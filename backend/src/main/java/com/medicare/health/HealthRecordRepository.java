package com.medicare.health;

import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import com.medicare.user.entity.User;
import java.util.List;

public interface HealthRecordRepository extends JpaRepository<HealthRecord, Long> {
    List<HealthRecord> findByUserIdOrderByRecordedAtDesc(Long userId);
    @Modifying
    @Query("update HealthRecord r set r.user = :target where r.user.id = :source")
    int transfer(@Param("source") Long source, @Param("target") User target);
}
