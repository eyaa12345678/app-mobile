package com.medicare.identity;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;
@Entity @Getter @Setter @NoArgsConstructor
@Table(indexes = @Index(columnList = "primary_user_id,status"))
public class AccountMergeRequest {
    public enum Status { PENDING_VERIFICATION, AWAITING_REVIEW, COMPLETED, REJECTED, CANCELLED }
    @Id @Column(length = 36) private String id;
    private Long primaryUserId;
    private Long secondaryUserId;
    private String targetEmail;
    private String primaryChallengeId;
    private String secondaryChallengeId;
    @Enumerated(EnumType.STRING) private Status status;
    @Column(length = 500) private String reason;
    private Instant requestedAt;
    private Instant verifiedAt;
    private long primaryVersion;
    private long secondaryVersion;
    private Long reviewerId;
    private Instant reviewedAt;
    @Column(length = 1000) private String decisionNote;
}
