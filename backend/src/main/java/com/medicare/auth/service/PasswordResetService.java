package com.medicare.auth.service;

import com.medicare.auth.dto.AuthDtos;
import com.medicare.common.ApiException;
import com.medicare.user.entity.User;
import com.medicare.user.repository.UserRepository;
import com.medicare.security.account.PasswordLifecycle;
import com.medicare.security.account.AccountAccess;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PasswordResetService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int MAX_ATTEMPTS = 5;
    private final UserRepository userRepository;
    private final PasswordLifecycle passwords;
    private final AccountAccess accounts;
    private final PasswordEncoder passwordEncoder;
    private final PasswordResetMailService mailService;

    @Transactional
    public AuthDtos.MessageResponse requestCode(String email) {
        mailService.ensureAvailable();
        var resolved = accounts.resolve(normalizeEmail(email));
        var account = resolved.map(u -> accounts.lock(u.getId()));
        if (account.isPresent()) {
            User user = account.get();
            Instant now = Instant.now();
            // Return the same response for unknown accounts and repeated requests.
            if (user.getResetCodeRequestedAt() == null
                    || !now.isBefore(user.getResetCodeRequestedAt().plusSeconds(60))) {
                String code = String.format(Locale.ROOT, "%06d", RANDOM.nextInt(1_000_000));
                user.setResetCodeHash(passwordEncoder.encode(code));
                user.setResetCodeExpiresAt(now.plus(10, ChronoUnit.MINUTES));
                user.setResetCodeRequestedAt(now);
                user.setResetCodeAttempts(0);
                mailService.sendCode(user.getEmail(), code);
                userRepository.save(user);
            }
        }
        return new AuthDtos.MessageResponse("If this email exists, a reset code has been sent.");
    }

    // Failed guesses must be committed so that the attempt limit cannot be bypassed.
    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.MessageResponse resetPassword(AuthDtos.ResetPasswordRequest request) {
        PasswordPolicy.validate(request.newPassword());
        User user = accounts.resolve(normalizeEmail(request.email())).map(u -> accounts.lock(u.getId()))
                .orElseThrow(this::invalidCode);
        if (user.getResetCodeHash() == null || user.getResetCodeExpiresAt() == null
                || !Instant.now().isBefore(user.getResetCodeExpiresAt())
                || user.getResetCodeAttempts() >= MAX_ATTEMPTS) {
            throw invalidCode();
        }
        user.setResetCodeAttempts(user.getResetCodeAttempts() + 1);
        if (!passwordEncoder.matches(request.code(), user.getResetCodeHash())) {
            userRepository.save(user);
            throw invalidCode();
        }
        passwords.replace(user, request.newPassword());
        user.setEmailVerified(true);
        user.setResetCodeHash(null);
        user.setResetCodeExpiresAt(null);
        user.setResetCodeAttempts(0);

        userRepository.save(user);
        return new AuthDtos.MessageResponse("Password updated. Please sign in again.");
    }

    private ApiException invalidCode() {
        return new ApiException(HttpStatus.BAD_REQUEST, "Invalid or expired reset code");
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
