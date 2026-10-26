package com.medicare.security.account;
import com.medicare.auth.dto.AuthDtos;
import com.medicare.auth.service.CompromisedPasswordChecker;
import com.medicare.roles.*;
import com.medicare.user.entity.*;
import com.medicare.user.dto.UserDtos;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/security") @RequiredArgsConstructor
public class AccountSecurityController {
    private final AccountAccess accounts;
    private final AccountSecurityService security;
    private final RecoveryCodeService recovery;
    private final RoleChangeService roles;
    private final PasswordLifecycle passwords;
    private final SecurityAuditRepository audit;
    private final CompromisedPasswordChecker checker;
    public record ActionRequest(@NotNull AccountSecurityService.Action action, @Size(max = 100) String currentPassword) {}
    public record RoleRequest(@NotNull Role requestedRole, @NotBlank @Size(min = 10, max = 500) String reason) {}
    public record Decision(@NotNull Boolean approve, @NotBlank @Size(min = 10, max = 500) String note) {}
    public record Incident(@NotBlank @Size(min = 10, max = 500) String reason) {}
    public record Overview(UserDtos.UserResponse user, long recoveryCodesRemaining, boolean compromisedPasswordCheck) {}
    @GetMapping @Transactional(readOnly = true)
    public Overview overview(Authentication authentication) {
        User user = accounts.current(authentication);
        return new Overview(UserDtos.UserResponse.from(user), recovery.remaining(user.getId()), checker.isEnabled());
    }
    @PostMapping("/challenge")
    public AuthDtos.AuthResponse challenge(@Valid @RequestBody ActionRequest request, Authentication authentication) {
        return security.request(accounts.current(authentication), request.action(), request.currentPassword());
    }
    @PostMapping("/confirm")
    public AuthDtos.AuthResponse confirm(@Valid @RequestBody AuthDtos.VerifyRequest request, Authentication authentication) {
        return security.confirm(accounts.current(authentication), request);
    }
    @GetMapping("/role-requests")
    public List<RoleChangeService.View> ownRoles(Authentication authentication) { return roles.own(accounts.current(authentication).getId()); }
    @PostMapping("/role-requests")
    public RoleChangeService.View requestRole(@Valid @RequestBody RoleRequest request, Authentication authentication) {
        return roles.request(accounts.current(authentication), request.requestedRole(), request.reason().trim());
    }
    @GetMapping("/admin/role-requests") @PreAuthorize("hasRole('ADMIN')")
    public List<RoleChangeService.View> pendingRoles(Authentication authentication) { accounts.admin(authentication); return roles.pending(); }
    @PostMapping("/admin/role-requests/{id}/decision") @PreAuthorize("hasRole('ADMIN')")
    public RoleChangeService.View decideRole(@PathVariable Long id, @Valid @RequestBody Decision request, Authentication authentication) {
        return roles.decide(id, accounts.admin(authentication), request.approve(), request.note().trim());
    }
    @PostMapping("/admin/users/{id}/incident") @PreAuthorize("hasRole('ADMIN')") @Transactional
    public AuthDtos.MessageResponse incident(@PathVariable Long id, @Valid @RequestBody Incident request, Authentication authentication) {
        var admin = accounts.admin(authentication);
        passwords.incident(accounts.lock(id), admin.getId(), request.reason().trim());
        recovery.revoke(id);
        return new AuthDtos.MessageResponse("PASSWORD_RESET_REQUIRED");
    }
    @GetMapping("/admin/audit") @PreAuthorize("hasRole('ADMIN')")
    public List<SecurityAuditEvent> audit(Authentication authentication) { accounts.admin(authentication); return audit.findTop100ByOrderByOccurredAtDesc(); }
}
