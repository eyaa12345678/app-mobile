package com.medicare.security.account;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
@Table(indexes = @Index(columnList = "user_id,code_hash"))
public class RecoveryCode {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    private Long userId;
    @Column(nullable = false, length = 64) private String codeHash;
    private Instant usedAt;
}
