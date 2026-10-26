package com.medicare.roles;
import com.medicare.user.entity.Role;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
@Table(indexes = @Index(columnList = "user_id,status"))
public class RoleChangeRequest {
    public enum Status { PENDING, APPROVED, REJECTED }
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    private Long userId;
    @Enumerated(EnumType.STRING) private Role previousRole;
    @Enumerated(EnumType.STRING) private Role requestedRole;
    @Enumerated(EnumType.STRING) private Status status;
    @Column(length = 500) private String reason;
    private Instant requestedAt;
    private Long reviewerId;
    private Instant reviewedAt;
    @Column(length = 500) private String decisionNote;
}
