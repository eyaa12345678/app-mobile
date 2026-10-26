package com.medicare.security.account;
import com.medicare.auth.dto.AuthDtos;
import com.medicare.common.ApiException;
import com.medicare.user.entity.User;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service @RequiredArgsConstructor
public class AccountSecurityService {
    public enum Action { VERIFY_EMAIL, MFA_ENABLE, MFA_DISABLE, RECOVERY_ROTATE }
    private final AccountAccess accounts;
    private final EmailChallengeService challenges;
    private final PasswordEncoder encoder;
    private final RecoveryCodeService recovery;
    private final SessionIssuer sessions;
    private final SecurityAudit audit;
    @Transactional
    public AuthDtos.AuthResponse request(User actor, Action action, String currentPassword) {
        User user = accounts.lock(actor.getId());
        if (action != Action.VERIFY_EMAIL && (currentPassword == null || !encoder.matches(currentPassword, user.getPassword()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Current password is incorrect");
        }
        if ((action == Action.MFA_DISABLE || action == Action.RECOVERY_ROTATE) && !user.isMfaEnabled()) {
            throw new ApiException(HttpStatus.CONFLICT, "MFA_NOT_ENABLED");
        }
        return AuthDtos.AuthResponse.challenge(challenges.issue(user, EmailChallenge.Purpose.valueOf(action.name())));
    }
    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.AuthResponse confirm(User actor, AuthDtos.VerifyRequest request) {
        var c = challenges.check(request.challengeId(), Set.of(EmailChallenge.Purpose.VERIFY_EMAIL, EmailChallenge.Purpose.MFA_ENABLE,
                EmailChallenge.Purpose.MFA_DISABLE, EmailChallenge.Purpose.RECOVERY_ROTATE), request.code());
        if (!c.getUserId().equals(actor.getId())) throw new ApiException(HttpStatus.FORBIDDEN, "Access denied");
        User user = accounts.lock(actor.getId());
        List<String> codes = List.of();
        user.setEmailVerified(true);
        if (c.getPurpose() == EmailChallenge.Purpose.MFA_ENABLE || c.getPurpose() == EmailChallenge.Purpose.RECOVERY_ROTATE) {
            user.setMfaEnabled(true); codes = recovery.rotate(user.getId()); AccountAccess.revoke(user);
        } else if (c.getPurpose() == EmailChallenge.Purpose.MFA_DISABLE) {
            user.setMfaEnabled(false); recovery.revoke(user.getId()); AccountAccess.revoke(user);
        }
        challenges.consume(c);
        audit.record(actor.getId(), user.getId(), c.getPurpose().name(), "Fresh email proof verified");
        return sessions.issue(user, codes);
    }
}
