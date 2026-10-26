package com.medicare.identity;
import com.medicare.common.ApiException;
import com.medicare.security.account.*;
import com.medicare.user.entity.*;
import com.medicare.user.repository.UserRepository;
import com.medicare.appointment.AppointmentRepository;
import com.medicare.medication.MedicationRepository;
import com.medicare.health.HealthRecordRepository;
import java.time.Instant;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service @RequiredArgsConstructor
public class AccountMergeService {
    private final AccountMergeRepository requests;
    private final UserRepository users;
    private final AccountAccess accounts;
    private final EmailChallengeService challenges;
    private final RecoveryCodeService recovery;
    private final SecurityAudit audit;
    private final AppointmentRepository appointments;
    private final MedicationRepository medications;
    private final HealthRecordRepository health;
    public record View(String id, Long primaryUserId, Long secondaryUserId, String targetEmail,
                       String primaryChallengeId, String secondaryChallengeId, AccountMergeRequest.Status status,
                       String reason, Instant requestedAt, Instant verifiedAt, Long reviewerId, String decisionNote,
                       Map<String, List<String>> conflicts, Map<String, String> primaryProfile, Map<String, String> secondaryProfile) {}
    public View view(AccountMergeRequest r, boolean admin) {
        Map<String, List<String>> conflicts = Map.of();
        Map<String, String> a = Map.of(), b = Map.of();
        boolean proven = r.getVerifiedAt() != null;
        if (admin && proven && r.getSecondaryUserId() != null) {
            a = profile(users.findById(r.getPrimaryUserId()).orElseThrow());
            b = profile(users.findById(r.getSecondaryUserId()).orElseThrow()); conflicts = conflicts(a, b);
        }
        return new View(r.getId(), r.getPrimaryUserId(), admin && proven ? r.getSecondaryUserId() : null,
                r.getTargetEmail(), r.getPrimaryChallengeId(), r.getSecondaryChallengeId(), r.getStatus(), r.getReason(),
                r.getRequestedAt(), r.getVerifiedAt(), r.getReviewerId(), r.getDecisionNote(), conflicts, a, b);
    }
    @Transactional
    public View request(User actor, String targetEmail, String reason) {
        var active = requests.findByPrimaryUserIdOrderByRequestedAtDesc(actor.getId()).stream()
                .filter(r -> r.getStatus() == AccountMergeRequest.Status.PENDING_VERIFICATION || r.getStatus() == AccountMergeRequest.Status.AWAITING_REVIEW).toList();
        if (!active.isEmpty()) throw conflict("MERGE_REQUEST_PENDING");
        var target = accounts.resolve(targetEmail);
        if (target.isPresent() && target.get().getId().equals(actor.getId())) throw conflict("MERGE_SAME_ACCOUNT");
        lockPair(actor.getId(), target.map(User::getId).orElse(null));
        User primary = accounts.lock(actor.getId());
        var r = new AccountMergeRequest(); r.setId(UUID.randomUUID().toString()); r.setPrimaryUserId(primary.getId());
        r.setTargetEmail(targetEmail.trim().toLowerCase(Locale.ROOT)); r.setReason(reason); r.setRequestedAt(Instant.now());
        r.setStatus(AccountMergeRequest.Status.PENDING_VERIFICATION);
        r.setPrimaryChallengeId(challenges.issue(primary, EmailChallenge.Purpose.MERGE_PRIMARY).getId());
        r.setSecondaryChallengeId(UUID.randomUUID().toString());
        if (target.isPresent()) {
            User secondary = accounts.lock(target.get().getId()); r.setSecondaryUserId(secondary.getId());
            r.setSecondaryChallengeId(challenges.issue(secondary, EmailChallenge.Purpose.MERGE_SECONDARY).getId());
        }
        requests.save(r); audit.record(primary.getId(), primary.getId(), "MERGE_REQUESTED", "Request " + r.getId());
        return view(r, false);
    }
    @Transactional(noRollbackFor = ApiException.class)
    public View verify(String id, User actor, String primaryCode, String secondaryCode) {
        var r = ownLocked(id, actor);
        if (r.getStatus() != AccountMergeRequest.Status.PENDING_VERIFICATION) throw conflict("REQUEST_ALREADY_REVIEWED");
        lockPair(r.getPrimaryUserId(), r.getSecondaryUserId());
        var a = challenges.check(r.getPrimaryChallengeId(), Set.of(EmailChallenge.Purpose.MERGE_PRIMARY), primaryCode);
        var b = challenges.check(r.getSecondaryChallengeId(), Set.of(EmailChallenge.Purpose.MERGE_SECONDARY), secondaryCode);
        if (!a.getUserId().equals(r.getPrimaryUserId()) || !b.getUserId().equals(r.getSecondaryUserId())) throw challenges.invalid();
        User primary = accounts.lock(r.getPrimaryUserId()); User secondary = accounts.lock(r.getSecondaryUserId());
        if (primary.isPasswordResetRequired() || secondary.isPasswordResetRequired()) throw conflict("ACCOUNT_REQUIRES_VERIFICATION");
        primary.setEmailVerified(true); secondary.setEmailVerified(true);
        challenges.consume(a); challenges.consume(b); r.setVerifiedAt(Instant.now());
        r.setPrimaryVersion(AccountAccess.version(primary)); r.setSecondaryVersion(AccountAccess.version(secondary));
        r.setStatus(AccountMergeRequest.Status.AWAITING_REVIEW);
        audit.record(actor.getId(), secondary.getId(), "MERGE_OWNERSHIP_VERIFIED", "Request " + id);
        return view(r, false);
    }
    @Transactional
    public View cancel(String id, User actor) {
        var r = ownLocked(id, actor);
        if (r.getStatus() != AccountMergeRequest.Status.PENDING_VERIFICATION && r.getStatus() != AccountMergeRequest.Status.AWAITING_REVIEW) throw conflict("REQUEST_ALREADY_REVIEWED");
        r.setStatus(AccountMergeRequest.Status.CANCELLED);
        audit.record(actor.getId(), actor.getId(), "MERGE_CANCELLED", "Request " + id); return view(r, false);
    }
    @Transactional
    public View decide(String id, User admin, boolean approve, String note, Map<String, String> selections) {
        var r = requests.findForUpdate(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Request not found"));
        if (r.getStatus() != AccountMergeRequest.Status.AWAITING_REVIEW) throw conflict("REQUEST_ALREADY_REVIEWED");
        if (admin.getId().equals(r.getPrimaryUserId()) || admin.getId().equals(r.getSecondaryUserId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "SELF_APPROVAL_FORBIDDEN");
        }
        if (approve) merge(r, admin, selections == null ? Map.of() : selections);
        else r.setStatus(AccountMergeRequest.Status.REJECTED);
        r.setReviewerId(admin.getId()); r.setReviewedAt(Instant.now()); r.setDecisionNote(note);
        audit.record(admin.getId(), r.getPrimaryUserId(), approve ? "MERGE_APPROVED" : "MERGE_REJECTED", "Request " + id + ": " + note);
        return view(r, true);
    }
    private void merge(AccountMergeRequest r, User admin, Map<String, String> selections) {
        lockPair(r.getPrimaryUserId(), r.getSecondaryUserId());
        User a = accounts.lock(r.getPrimaryUserId()), b = accounts.lock(r.getSecondaryUserId());
        if (r.getVerifiedAt() == null || r.getVerifiedAt().plusSeconds(86400).isBefore(Instant.now())
                || AccountAccess.version(a) != r.getPrimaryVersion() || AccountAccess.version(b) != r.getSecondaryVersion()
                || !a.isEmailVerified() || !b.isEmailVerified() || a.isPasswordResetRequired() || b.isPasswordResetRequired()
                || a.getMergedIntoId() != null || b.getMergedIntoId() != null) throw conflict("MERGE_PROOF_EXPIRED");
        // Professional/admin rights are never inherited or combined by identity resolution.
        if (a.getRole() != Role.USER || b.getRole() != Role.USER) throw conflict("MERGE_PRIVILEGED_ACCOUNTS_FORBIDDEN");
        Map<String, String> first = profile(a), second = profile(b);
        var conflictFields = conflicts(first, second);
        if (!first.keySet().containsAll(selections.keySet()) || selections.values().stream().anyMatch(v -> !Set.of("PRIMARY", "SECONDARY").contains(v))) {
            throw conflict("MERGE_INVALID_SELECTION");
        }
        if (!selections.keySet().containsAll(conflictFields.keySet())) throw conflict("MERGE_CONFLICTS_UNRESOLVED");
        Map<String, String> result = new LinkedHashMap<>(first);
        for (String key : first.keySet()) {
            if ("SECONDARY".equals(selections.get(key)) || (first.get(key).isBlank() && !conflictFields.containsKey(key))) result.put(key, second.get(key));
        }
        a.setFullName(result.get("fullName")); a.setPhoneNumber(blankToNull(result.get("phoneNumber")));
        a.setBirthDate(result.get("birthDate").isBlank() ? null : java.time.LocalDate.parse(result.get("birthDate")));
        a.setBio(blankToNull(result.get("bio"))); a.setProfilePhotoUrl(blankToNull(result.get("profilePhotoUrl")));
        int count = appointments.transfer(b.getId(), a) + medications.transfer(b.getId(), a) + health.transfer(b.getId(), a);
        a.setMfaEnabled(a.isMfaEnabled() || b.isMfaEnabled());
        AccountAccess.revoke(a); AccountAccess.revoke(b); recovery.revoke(b.getId());
        b.setMergedIntoId(a.getId()); b.setResetCodeHash(null); b.setResetCodeExpiresAt(null);
        users.findByMergedIntoId(b.getId()).forEach(alias -> { alias.setMergedIntoId(a.getId()); AccountAccess.revoke(alias); });
        r.setStatus(AccountMergeRequest.Status.COMPLETED);
        audit.record(admin.getId(), a.getId(), "ACCOUNTS_MERGED", "Request " + r.getId() + "; secondary=" + b.getId() + "; records=" + count + "; fields=" + selections);
    }
    @Transactional(readOnly = true)
    public List<View> own(Long id) { return requests.findByPrimaryUserIdOrderByRequestedAtDesc(id).stream().map(r -> view(r, false)).toList(); }
    @Transactional(readOnly = true)
    public List<View> pending() { return requests.findByStatusOrderByRequestedAtAsc(AccountMergeRequest.Status.AWAITING_REVIEW).stream().map(r -> view(r, true)).toList(); }
    public record Duplicate(Long primaryUserId, Long secondaryUserId, String reason) {}
    @Transactional(readOnly = true)
    public List<Duplicate> duplicates() {
        List<Duplicate> results = new ArrayList<>();
        var verified = users.findAll().stream().filter(u -> u.isEmailVerified() && u.getMergedIntoId() == null).toList();
        Map<String, Long> identifiers = new HashMap<>();
        Map<String, User> gmailMailboxes = new HashMap<>();
        for (User u : verified) {
            List<String> keys = new ArrayList<>(); keys.add("email:" + u.getEmail().trim().toLowerCase(Locale.ROOT));
            if (u.getUsername() != null) keys.add("username:" + u.getUsername().trim().toLowerCase(Locale.ROOT));
            String mailbox = gmailMailbox(u.getEmail());
            if (mailbox != null) {
                User previous = gmailMailboxes.putIfAbsent(mailbox, u);
                if (previous != null && !previous.getEmail().equalsIgnoreCase(u.getEmail())) {
                    results.add(new Duplicate(previous.getId(), u.getId(), "Alias Gmail vérifiés : boîte de réception potentiellement commune, identité à confirmer"));
                }
            }
            for (String key : keys) {
                Long previous = identifiers.putIfAbsent(key, u.getId());
                if (previous != null && !previous.equals(u.getId())) results.add(new Duplicate(previous, u.getId(), "Identifiant identique sur deux comptes dont l'email est vérifié"));
            }
        }
        requests.findByStatusOrderByRequestedAtAsc(AccountMergeRequest.Status.AWAITING_REVIEW)
                .forEach(r -> results.add(new Duplicate(r.getPrimaryUserId(), r.getSecondaryUserId(), "Rapprochement demandé ; propriété des deux emails prouvée")));
        return results;
    }
    // Only public gmail.com addresses: organization domains may treat dots differently.
    // https://support.google.com/mail/answer/7436150
    private String gmailMailbox(String email) {
        String value = email.trim().toLowerCase(Locale.ROOT);
        if (!value.endsWith("@gmail.com")) return null;
        String local = value.substring(0, value.length() - "@gmail.com".length());
        int tag = local.indexOf('+');
        if (tag >= 0) local = local.substring(0, tag);
        if (!local.matches("[a-z0-9.]+")) return null;
        local = local.replace(".", "");
        return local.isEmpty() ? null : local;
    }

    private AccountMergeRequest ownLocked(String id, User actor) {
        var r = requests.findForUpdate(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Request not found"));
        if (!r.getPrimaryUserId().equals(actor.getId())) throw new ApiException(HttpStatus.FORBIDDEN, "Access denied"); return r;
    }
    private void lockPair(Long a, Long b) {
        java.util.stream.Stream.of(a, b).filter(Objects::nonNull).distinct().sorted().forEach(accounts::lock);
    }
    private Map<String, String> profile(User u) {
        var result = new LinkedHashMap<String, String>(); result.put("fullName", u.getFullName()); result.put("phoneNumber", Objects.toString(u.getPhoneNumber(), ""));
        result.put("birthDate", Objects.toString(u.getBirthDate(), "")); result.put("bio", Objects.toString(u.getBio(), "")); result.put("profilePhotoUrl", Objects.toString(u.getProfilePhotoUrl(), "")); return result;
    }
    private Map<String, List<String>> conflicts(Map<String, String> a, Map<String, String> b) {
        var result = new LinkedHashMap<String, List<String>>();
        a.forEach((k,v) -> { if (!v.isBlank() && !b.get(k).isBlank() && !v.trim().equals(b.get(k).trim())) result.put(k, List.of(v, b.get(k))); }); return result;
    }
    private String blankToNull(String value) { return value.isBlank() ? null : value; }
    private ApiException conflict(String message) { return new ApiException(HttpStatus.CONFLICT, message); }
}
