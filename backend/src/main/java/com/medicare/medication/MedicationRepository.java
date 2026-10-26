package com.medicare.medication;

import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import com.medicare.user.entity.User;
import java.util.List;

public interface MedicationRepository extends JpaRepository<Medication, Long> {
    List<Medication> findByUserIdOrderByName(Long userId);
    @Modifying
    @Query("update Medication r set r.user = :target where r.user.id = :source")
    int transfer(@Param("source") Long source, @Param("target") User target);
}
