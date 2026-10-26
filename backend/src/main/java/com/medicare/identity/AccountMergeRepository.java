package com.medicare.identity;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.*;
public interface AccountMergeRepository extends JpaRepository<AccountMergeRequest, String> {
    List<AccountMergeRequest> findByPrimaryUserIdOrderByRequestedAtDesc(Long userId);
    List<AccountMergeRequest> findByStatusOrderByRequestedAtAsc(AccountMergeRequest.Status status);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select m from AccountMergeRequest m where m.id = :id")
    Optional<AccountMergeRequest> findForUpdate(@Param("id") String id);
}
