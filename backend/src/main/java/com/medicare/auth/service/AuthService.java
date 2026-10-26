package com.medicare.auth.service;
import com.medicare.auth.dto.AuthDtos;
import com.medicare.common.ApiException;
import com.medicare.roles.RoleChangeService;
import com.medicare.security.account.*;
import com.medicare.user.entity.*;
import com.medicare.user.repository.UserRepository;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service @RequiredArgsConstructor
public class AuthService {
    private static final String DUMMY_HASH = new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder().encode(UUID.randomUUID().toString());
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final PasswordLifecycle passwords;
    private final AccountAccess accounts;
    private final EmailChallengeService challenges;
    private final RecoveryCodeService recovery;
    private final SessionIssuer sessions;
    private final SecurityAudit audit;
    private final RoleChangeService roles;
    private final PasswordResetService passwordResetService;
    private final PasswordResetMailService mail;

    @Transactional
    public AuthDtos.AuthResponse register(AuthDtos.RegisterRequest request) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        String username = request.username() == null ? null : request.username().trim().toLowerCase(Locale.ROOT);
        if (users.existsByEmailIgnoreCase(email)) throw new ApiException(HttpStatus.CONFLICT, "Email already exists");
        if (username != null && users.existsByUsernameIgnoreCase(username)) throw new ApiException(HttpStatus.CONFLICT, "IDENTIFIER_ALREADY_USED");
        String hash = passwords.prepare(request.password());
        User user = users.saveAndFlush(User.builder().fullName(request.fullName().trim()).email(email).username(username)
                .password(hash).role(Role.USER).mfaEnabled(true).build());
        if (request.requestedRole() != null && request.requestedRole() != Role.USER) {
            roles.request(user, request.requestedRole(), "Rôle demandé à l'inscription. Vérification professionnelle requise avant approbation.");
        }
        audit.record(user.getId(), user.getId(), "ACCOUNT_REGISTERED", "Email verification pending");
        return AuthDtos.AuthResponse.challenge(challenges.issue(user, EmailChallenge.Purpose.SIGNUP));
    }

    @Transactional
    public AuthDtos.AuthResponse login(AuthDtos.LoginRequest request) {
        String identifier = request.identifier() == null || request.identifier().isBlank() ? request.email() : request.identifier();
        User user = passwordAccount(identifier, request.password());
        if (!user.isEmailVerified()) return AuthDtos.AuthResponse.challenge(challenges.issue(user, EmailChallenge.Purpose.SIGNUP));
        if (user.isMfaEnabled()) return AuthDtos.AuthResponse.challenge(challenges.issue(user, EmailChallenge.Purpose.MFA_LOGIN));
        audit.record(user.getId(), user.getId(), "LOGIN_PASSWORD", "");
        return sessions.issue(user);
    }

    @Transactional
    public AuthDtos.AuthResponse passwordless(AuthDtos.ForgotPasswordRequest request) {
        mail.ensureAvailable();
        var found = accounts.resolve(request.email());
        if (found.isEmpty()) return AuthDtos.AuthResponse.anonymousChallenge(UUID.randomUUID().toString(), "PASSWORDLESS");
        User user = accounts.lock(found.get().getId());
        // Alias logins send codes to the primary, verified contact. No target account data is disclosed.
        try { return AuthDtos.AuthResponse.challenge(challenges.issue(user, EmailChallenge.Purpose.PASSWORDLESS)); }
        catch (ApiException ex) {
            if (ex.getStatus() == HttpStatus.TOO_MANY_REQUESTS) return AuthDtos.AuthResponse.anonymousChallenge(UUID.randomUUID().toString(), "PASSWORDLESS");
            throw ex;
        }
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.AuthResponse verify(AuthDtos.VerifyRequest request) {
        var c = challenges.check(request.challengeId(), Set.of(EmailChallenge.Purpose.SIGNUP, EmailChallenge.Purpose.MFA_LOGIN,
                EmailChallenge.Purpose.PASSWORDLESS), request.code());
        User user = accounts.lock(c.getUserId()); requireUsablePassword(user);
        List<String> codes = List.of();
        if (c.getPurpose() == EmailChallenge.Purpose.PASSWORDLESS && user.isMfaEnabled()) {
            if (request.recoveryCode() == null || request.recoveryCode().isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORDLESS_RECOVERY_REQUIRED");
            }
            recovery.consume(user.getId(), request.recoveryCode());
        }
        if (c.getPurpose() == EmailChallenge.Purpose.SIGNUP && user.isMfaEnabled() && recovery.remaining(user.getId()) == 0) {
            codes = recovery.rotate(user.getId());
        }
        challenges.consume(c); user.setEmailVerified(true);
        audit.record(user.getId(), user.getId(), "LOGIN_" + c.getPurpose().name(), "Email proof verified");
        return sessions.issue(user, codes);
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.AuthResponse recover(AuthDtos.VerifyRequest request) {
        var c = challenges.active(request.challengeId(), Set.of(EmailChallenge.Purpose.MFA_LOGIN));
        c.setAttempts(c.getAttempts() + 1);
        User user = accounts.lock(c.getUserId()); requireUsablePassword(user);
        recovery.consume(user.getId(), request.code()); challenges.consume(c);
        audit.record(user.getId(), user.getId(), "LOGIN_RECOVERY_CODE", "Single-use code consumed");
        return sessions.issue(user);
    }
    @Transactional
    public AuthDtos.AuthResponse resend(String id) {
        var previous = challenges.active(id, Set.of(EmailChallenge.Purpose.SIGNUP, EmailChallenge.Purpose.MFA_LOGIN, EmailChallenge.Purpose.PASSWORDLESS));
        return AuthDtos.AuthResponse.challenge(challenges.issue(accounts.lock(previous.getUserId()), previous.getPurpose()));
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.AuthResponse recoveryLogin(AuthDtos.RecoveryLoginRequest request) {
        User user = passwordAccount(request.identifier(), request.password());
        if (!user.isMfaEnabled() || !user.isEmailVerified()) throw new ApiException(HttpStatus.BAD_REQUEST, "MFA_NOT_ENABLED");
        recovery.consume(user.getId(), request.code());
        audit.record(user.getId(), user.getId(), "LOGIN_RECOVERY_CODE", "Password and single-use backup proof; email delivery not required");
        return sessions.issue(user);
    }

    private User passwordAccount(String identifier, String password) {
        var candidate = accounts.resolve(identifier);
        if (candidate.isEmpty()) {
            encoder.matches(password, DUMMY_HASH);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }
        User user = accounts.lock(candidate.get().getId());
        if (!encoder.matches(password, user.getPassword())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }
        requireUsablePassword(user);
        return user;
    }

    private void requireUsablePassword(User user) {
        if (user.isPasswordResetRequired()) throw new ApiException(HttpStatus.LOCKED, "PASSWORD_RESET_REQUIRED");
    }
    public AuthDtos.MessageResponse forgotPassword(AuthDtos.ForgotPasswordRequest request) { return passwordResetService.requestCode(request.email()); }
    public AuthDtos.MessageResponse resetPassword(AuthDtos.ResetPasswordRequest request) { return passwordResetService.resetPassword(request); }
    public AuthDtos.MessageResponse logout() { return new AuthDtos.MessageResponse("Remove the token on the client."); }
}
