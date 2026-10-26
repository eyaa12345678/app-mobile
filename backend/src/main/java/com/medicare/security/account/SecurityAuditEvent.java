package com.medicare.security.account;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
public class SecurityAuditEvent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    private Long actorId;
    private Long subjectId;
    @Column(nullable = false, length = 80) private String action;
    @Column(length = 1000) private String detail;
    @Column(nullable = false) private Instant occurredAt;
}
