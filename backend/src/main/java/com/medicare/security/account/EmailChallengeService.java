package com.medicare.security.account;
import com.medicare.auth.service.PasswordResetMailService;
import com.medicare.common.ApiException;
import com.medicare.user.entity.User;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class EmailChallengeService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final EmailChallengeRepository challenges;
    private final PasswordEncoder encoder;
    private final PasswordResetMailService mail;
    private final AccountAccess accounts;
    @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entities;
    // Caller holds the account lock and a transaction. Earlier challenges are never returned to a new caller.
    public EmailChallenge issue(User user, EmailChallenge.Purpose purpose) {
        mail.ensureAvailable();
        Instant now = Instant.now();
        var previous = challenges.findFirstByUserIdAndPurposeOrderByCreatedAtDesc(user.getId(), purpose);
        if (previous.isPresent() && now.isBefore(previous.get().getCreatedAt().plusSeconds(60))) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "OTP_COOLDOWN");
        }
        challenges.findByUserIdAndPurposeAndConsumedAtIsNull(user.getId(), purpose).forEach(c -> c.setConsumedAt(now));
        String code = String.format(Locale.ROOT, "%06d", RANDOM.nextInt(1_000_000));
        var c = new EmailChallenge();
        c.setId(UUID.randomUUID().toString()); c.setUserId(user.getId()); c.setPurpose(purpose); c.setCodeHash(encoder.encode(code));
        c.setEmailSnapshot(user.getEmail()); c.setTokenVersion(AccountAccess.version(user));
        c.setCreatedAt(now); c.setExpiresAt(now.plusSeconds(600));
        mail.sendVerificationCode(user.getEmail(), code, purpose.name());
        return challenges.save(c);
    }
    public EmailChallenge active(String id, Set<EmailChallenge.Purpose> purposes) {
        EmailChallenge snapshot = challenges.findById(id).orElseThrow(this::invalid);
        User user = accounts.lock(snapshot.getUserId());
        EmailChallenge c = challenges.findForUpdate(id).orElseThrow(this::invalid);
        entities.refresh(c, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        if (!purposes.contains(c.getPurpose()) || c.getConsumedAt() != null || c.getAttempts() >= 5
                || !Instant.now().isBefore(c.getExpiresAt()) || user.getMergedIntoId() != null
                || AccountAccess.version(user) != c.getTokenVersion()
                || !user.getEmail().equals(c.getEmailSnapshot())) throw invalid();
        return c;
    }
    public EmailChallenge check(String id, Set<EmailChallenge.Purpose> purposes, String code) {
        EmailChallenge c = active(id, purposes); c.setAttempts(c.getAttempts() + 1);
        if (code == null || !encoder.matches(code, c.getCodeHash())) throw invalid();
        return c;
    }
    public void consume(EmailChallenge c) { c.setConsumedAt(Instant.now()); }
    public ApiException invalid() { return new ApiException(HttpStatus.BAD_REQUEST, "CODE_INVALID_OR_EXPIRED"); }
}
