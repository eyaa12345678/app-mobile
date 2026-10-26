package com.medicare.identity;
import com.medicare.security.account.AccountAccess;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/security") @RequiredArgsConstructor
public class AccountMergeController {
    private final AccountAccess accounts;
    private final AccountMergeService merges;
    public record Request(@Email @NotBlank @Size(max = 160) String targetEmail, @NotBlank @Size(min = 10, max = 500) String reason) {}
    public record Proof(@NotBlank @Pattern(regexp = "[0-9]{6}") String primaryCode, @NotBlank @Pattern(regexp = "[0-9]{6}") String secondaryCode) {}
    public record Decision(@NotNull Boolean approve, @NotBlank @Size(min = 10, max = 500) String note, Map<String,String> fieldSources) {}
    @GetMapping("/merges")
    public List<AccountMergeService.View> own(Authentication authentication) { return merges.own(accounts.current(authentication).getId()); }
    @PostMapping("/merges")
    public AccountMergeService.View request(@Valid @RequestBody Request request, Authentication authentication) {
        return merges.request(accounts.current(authentication), request.targetEmail(), request.reason());
    }
    @PostMapping("/merges/{id}/verify")
    public AccountMergeService.View verify(@PathVariable String id, @Valid @RequestBody Proof proof, Authentication authentication) {
        return merges.verify(id, accounts.current(authentication), proof.primaryCode(), proof.secondaryCode());
    }
    @PostMapping("/merges/{id}/cancel")
    public AccountMergeService.View cancel(@PathVariable String id, Authentication authentication) { return merges.cancel(id, accounts.current(authentication)); }
    @GetMapping("/admin/merges") @PreAuthorize("hasRole('ADMIN')")
    public List<AccountMergeService.View> pending(Authentication authentication) { accounts.admin(authentication); return merges.pending(); }
    @GetMapping("/admin/duplicates") @PreAuthorize("hasRole('ADMIN')")
    public List<AccountMergeService.Duplicate> duplicates(Authentication authentication) { accounts.admin(authentication); return merges.duplicates(); }
    @PostMapping("/admin/merges/{id}/decision") @PreAuthorize("hasRole('ADMIN')")
    public AccountMergeService.View decide(@PathVariable String id, @Valid @RequestBody Decision decision, Authentication authentication) {
        return merges.decide(id, accounts.admin(authentication), decision.approve(), decision.note(), decision.fieldSources());
    }
}
