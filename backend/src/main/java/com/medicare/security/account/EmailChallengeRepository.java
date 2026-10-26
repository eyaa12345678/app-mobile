package com.medicare.security.account;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.*;
public interface EmailChallengeRepository extends JpaRepository<EmailChallenge, String> {
    Optional<EmailChallenge> findFirstByUserIdAndPurposeOrderByCreatedAtDesc(Long userId, EmailChallenge.Purpose purpose);
    List<EmailChallenge> findByUserIdAndPurposeAndConsumedAtIsNull(Long userId, EmailChallenge.Purpose purpose);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from EmailChallenge c where c.id = :id")
    Optional<EmailChallenge> findForUpdate(@Param("id") String id);
}
