package com.medicare.security.account;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
@Table(indexes = @Index(columnList = "user_id,changed_at"))
public class PasswordHistory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    private Long userId;
    @Column(nullable = false) private String passwordHash;
    @Column(nullable = false) private Instant changedAt;
}
