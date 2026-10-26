package com.medicare.security.account;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class SecurityAudit {
    private final SecurityAuditRepository events;
    public void record(Long actor, Long subject, String action, String detail) {
        var event = new SecurityAuditEvent();
        event.setActorId(actor); event.setSubjectId(subject);
        event.setAction(action); event.setDetail(detail); event.setOccurredAt(Instant.now());
        events.save(event);
    }
}
