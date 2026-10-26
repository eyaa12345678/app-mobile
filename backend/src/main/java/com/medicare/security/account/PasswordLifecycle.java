package com.medicare.security.account;
import com.medicare.auth.service.*;
import com.medicare.common.ApiException;
import com.medicare.user.entity.User;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class PasswordLifecycle {
    private final PasswordEncoder encoder;
    private final CompromisedPasswordChecker checker;
    private final PasswordHistoryRepository history;
    private final SecurityAudit audit;
    @Value("${app.security.password-history-size:5}") private int historySize;
    public String prepare(String raw) {
        PasswordPolicy.validate(raw); checker.rejectCompromised(raw); return encoder.encode(raw);
    }
    // Caller locks the user. Only BCrypt hashes are retained in history.
    public void replace(User user, String raw) {
        PasswordPolicy.validate(raw);
        var previous = history.findByUserIdOrderByChangedAtDescIdDesc(user.getId());
        int count = Math.max(0, Math.min(20, historySize) - 1);
        if (encoder.matches(raw, user.getPassword()) || previous.stream().limit(count)
                .anyMatch(h -> encoder.matches(raw, h.getPasswordHash()))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_REUSED");
        }
        String encoded = prepare(raw);
        if (count > 0) {
            var record = new PasswordHistory(); record.setUserId(user.getId());
            record.setPasswordHash(user.getPassword()); record.setChangedAt(Instant.now()); history.save(record);
            var all = history.findByUserIdOrderByChangedAtDescIdDesc(user.getId());
            if (all.size() > count) history.deleteAll(all.subList(count, all.size()));
        } else history.deleteAll(previous);
        user.setPassword(encoded); user.setPasswordResetRequired(false);
        user.setResetCodeHash(null); user.setResetCodeExpiresAt(null); user.setResetCodeAttempts(0);
        AccountAccess.revoke(user);
        audit.record(user.getId(), user.getId(), "PASSWORD_CHANGED", "Sessions revoked");
    }
    public void incident(User user, Long actorId, String reason) {
        user.setPasswordResetRequired(true); user.setResetCodeHash(null); user.setResetCodeExpiresAt(null);
        AccountAccess.revoke(user);
        audit.record(actorId, user.getId(), "PASSWORD_RESET_REQUIRED", reason);
    }
}
