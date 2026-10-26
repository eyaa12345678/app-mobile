package com.medicare.security.account;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface SecurityAuditRepository extends JpaRepository<SecurityAuditEvent, Long> {
    List<SecurityAuditEvent> findTop100ByOrderByOccurredAtDesc();
}
