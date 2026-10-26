package com.medicare.security.account;
import com.medicare.user.entity.*;
import com.medicare.user.repository.UserRepository;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
@Component @RequiredArgsConstructor
public class BootstrapAdministrator implements ApplicationRunner {
    private final UserRepository users;
    private final PasswordLifecycle passwords;
    private final SecurityAudit audit;
    @Value("${app.bootstrap-admin.email:}") private String email;
    @Value("${app.bootstrap-admin.password:}") private String password;
    @Override @Transactional public void run(ApplicationArguments arguments) {
        if (email.isBlank()) return;
        String normalized = email.trim().toLowerCase(Locale.ROOT);
        var existing = users.findByEmailIgnoreCase(normalized);
        if (existing.isPresent()) {
            User user = existing.get();
            if (user.getRole() == Role.ADMIN) return;
            if (!user.isEmailVerified() || user.getMergedIntoId() != null) throw new IllegalStateException("Verify the bootstrap account email before promoting it");
            user.setRole(Role.ADMIN); AccountAccess.revoke(user);
            audit.record(null, user.getId(), "ADMIN_BOOTSTRAPPED", "Explicit server-operator configuration"); return;
        }
        if (password.isBlank() || !normalized.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) throw new IllegalStateException("Valid BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD are required");
        User user = users.saveAndFlush(User.builder().fullName("Administrateur MediCare").email(normalized)
                .password(passwords.prepare(password)).role(Role.ADMIN).mfaEnabled(true).build());
        audit.record(null, user.getId(), "ADMIN_BOOTSTRAPPED", "Email verification required at first login");
    }
}
