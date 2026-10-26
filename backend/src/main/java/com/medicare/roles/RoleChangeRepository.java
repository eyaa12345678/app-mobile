package com.medicare.roles;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.*;
public interface RoleChangeRepository extends JpaRepository<RoleChangeRequest, Long> {
    List<RoleChangeRequest> findByUserIdOrderByRequestedAtDesc(Long userId);
    List<RoleChangeRequest> findByStatusOrderByRequestedAtAsc(RoleChangeRequest.Status status);
    boolean existsByUserIdAndStatus(Long userId, RoleChangeRequest.Status status);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select r from RoleChangeRequest r where r.id = :id")
    Optional<RoleChangeRequest> findForUpdate(@Param("id") Long id);
}
