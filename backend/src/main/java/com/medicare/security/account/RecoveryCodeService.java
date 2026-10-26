package com.medicare.security.account;
import com.medicare.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class RecoveryCodeService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final RecoveryCodeRepository codes;
    public List<String> rotate(Long userId) {
        codes.deleteByUserId(userId);
        List<String> result = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            byte[] bytes = new byte[16]; RANDOM.nextBytes(bytes);
            String raw = HexFormat.of().formatHex(bytes).toUpperCase(Locale.ROOT);
            String printable = String.join("-", raw.substring(0, 8), raw.substring(8, 16), raw.substring(16, 24), raw.substring(24));
            var c = new RecoveryCode(); c.setUserId(userId); c.setCodeHash(digest(printable)); codes.save(c); result.add(printable);
        }
        return result;
    }
    // Caller holds the account lock; consumption is atomic with challenge completion.
    public void consume(Long userId, String raw) {
        var c = codes.findByUserIdAndCodeHashAndUsedAtIsNull(userId, digest(raw == null ? "" : raw))
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "RECOVERY_CODE_INVALID"));
        c.setUsedAt(Instant.now());
    }
    public void revoke(Long userId) { codes.deleteByUserId(userId); }
    public long remaining(Long userId) { return codes.countByUserIdAndUsedAtIsNull(userId); }
    private String digest(String raw) {
        try {
            String normalized = raw.replace("-", "").replace(" ", "").trim().toUpperCase(Locale.ROOT);
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(normalized.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
