package com.medicare.appointment;

import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import com.medicare.user.entity.User;
import java.util.List;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {
    List<Appointment> findByUserIdOrderByDateTimeDesc(Long userId);
    @Modifying
    @Query("update Appointment r set r.user = :target where r.user.id = :source")
    int transfer(@Param("source") Long source, @Param("target") User target);
}
