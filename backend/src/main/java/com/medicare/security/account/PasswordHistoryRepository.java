package com.medicare.security.account;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface PasswordHistoryRepository extends JpaRepository<PasswordHistory, Long> {
    List<PasswordHistory> findByUserIdOrderByChangedAtDescIdDesc(Long userId);
}
