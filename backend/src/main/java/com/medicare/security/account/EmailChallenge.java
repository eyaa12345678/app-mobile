package com.medicare.security.account;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
@Table(indexes = @Index(columnList = "user_id,purpose,created_at"))
public class EmailChallenge {
    public enum Purpose { SIGNUP, MFA_LOGIN, PASSWORDLESS, VERIFY_EMAIL, MFA_ENABLE, MFA_DISABLE, RECOVERY_ROTATE, MERGE_PRIMARY, MERGE_SECONDARY }
    @Id @Column(length = 36) private String id;
    @Column(nullable = false) private Long userId;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 40) private Purpose purpose;
    @Column(nullable = false) private String codeHash;
    @Column(nullable = false) private String emailSnapshot;
    private long tokenVersion;
    private int attempts;
    @Column(nullable = false) private Instant createdAt;
    @Column(nullable = false) private Instant expiresAt;
    private Instant consumedAt;
}
