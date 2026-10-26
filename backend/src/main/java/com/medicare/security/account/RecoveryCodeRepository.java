package com.medicare.security.account;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface RecoveryCodeRepository extends JpaRepository<RecoveryCode, Long> {
    Optional<RecoveryCode> findByUserIdAndCodeHashAndUsedAtIsNull(Long userId, String codeHash);
    long countByUserIdAndUsedAtIsNull(Long userId);
    void deleteByUserId(Long userId);
}
