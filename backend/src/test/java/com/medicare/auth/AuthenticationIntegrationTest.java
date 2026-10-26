package com.medicare.auth;

import com.fasterxml.jackson.databind.*;
import com.medicare.auth.service.*;
import com.medicare.common.ApiException;
import com.medicare.security.JwtService;
import com.medicare.security.account.*;
import com.medicare.roles.*;
import com.medicare.identity.*;
import com.medicare.user.entity.*;
import com.medicare.user.repository.UserRepository;
import com.medicare.appointment.*;
import com.medicare.medication.MedicationRepository;
import com.medicare.health.HealthRecordRepository;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.*;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties = {"app.security.rate-limit-enabled=false", "app.bootstrap-admin.email="})
@AutoConfigureMockMvc @ActiveProfiles("dev")
class AuthenticationIntegrationTest {
    private static final String PASSWORD = "InitialPassword123!";
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired PasswordEncoder encoder;
    @Autowired JwtService jwt;
    @Autowired EmailChallengeRepository challenges;
    @Autowired RecoveryCodeRepository recovery;
    @Autowired RecoveryCodeService recoveryService;
    @Autowired PasswordHistoryRepository history;
    @Autowired RoleChangeRepository roles;
    @Autowired AccountMergeRepository merges;
    @Autowired SecurityAuditRepository audit;
    @Autowired AppointmentRepository appointments;
    @Autowired MedicationRepository medications;
    @Autowired HealthRecordRepository health;
    @Autowired PlatformTransactionManager transactionManager;
    @MockitoBean PasswordResetMailService mail;
    @MockitoBean CompromisedPasswordChecker checker;
    record Account(User user, String token, List<String> codes) {}

    @BeforeEach void clean() {
        appointments.deleteAll(); medications.deleteAll(); health.deleteAll();
        challenges.deleteAll(); recovery.deleteAll(); history.deleteAll(); roles.deleteAll(); merges.deleteAll(); audit.deleteAll();
        users.deleteAll(); reset(mail, checker);
    }
    private Account account(String email, Role role, boolean mfa) {
        User u = users.save(User.builder().fullName("Alice Martin").email(email).password(encoder.encode(PASSWORD))
                .role(role).emailVerified(true).mfaEnabled(mfa).build());
        List<String> codes = mfa ? new TransactionTemplate(transactionManager).execute(status -> recoveryService.rotate(u.getId())) : List.of();
        return new Account(u, jwt.generateToken(u), codes);
    }
    private ResultActions send(String path, String token, Map<String, ?> body) throws Exception {
        var request = post(path).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        if (token != null) request.header("Authorization", "Bearer " + token);
        return mvc.perform(request);
    }
    private JsonNode postJson(String path, String token, Map<String, ?> body, int status) throws Exception {
        return json.readTree(send(path, token, body).andExpect(status().is(status)).andReturn().getResponse().getContentAsString());
    }
    private String code(String email, String purpose) {
        var captor = ArgumentCaptor.forClass(String.class);
        verify(mail, atLeastOnce()).sendVerificationCode(eq(email), captor.capture(), eq(purpose));
        return captor.getValue();
    }
    private String wrong(String value) { return value.equals("000000") ? "111111" : "000000"; }
    private JsonNode login(String identifier, String password) throws Exception {
        return postJson("/api/auth/login", null, Map.of("identifier", identifier, "password", password), 200);
    }
    private JsonNode verifyChallenge(JsonNode c, String email, String purpose) throws Exception {
        return postJson("/api/auth/verify", null, Map.of("challengeId", c.get("challengeId").asText(), "code", code(email, purpose)), 200);
    }
    private void age(String email, EmailChallenge.Purpose purpose) {
        var c = challenges.findFirstByUserIdAndPurposeOrderByCreatedAtDesc(users.findByEmail(email).orElseThrow().getId(), purpose).orElseThrow();
        c.setCreatedAt(Instant.now().minusSeconds(61)); challenges.save(c);
    }
    private String resetCode(String email) throws Exception {
        postJson("/api/auth/forgot-password", null, Map.of("email", email), 200);
        var captor = ArgumentCaptor.forClass(String.class); verify(mail, atLeastOnce()).sendCode(eq(email), captor.capture()); return captor.getValue();
    }
    private Map<String, Object> registration(String email) { return new HashMap<>(Map.of("fullName", "Alice Martin", "email", email, "password", PASSWORD)); }

    @Test void signupRequiresEmailProofCreatesRecoveryCodesAndDoesNotGrantRequestedPrivileges() throws Exception {
        var body = registration("alice@example.fr"); body.put("requestedRole", "ADMIN"); body.put("username", "alice.martin");
        var challenge = postJson("/api/auth/register", null, body, 201);
        assertThat(challenge.get("token").isNull()).isTrue();
        User u = users.findByEmail("alice@example.fr").orElseThrow();
        assertThat(u.getRole()).isEqualTo(Role.USER); assertThat(u.isEmailVerified()).isFalse(); assertThat(u.isMfaEnabled()).isTrue();
        var session = verifyChallenge(challenge, "alice@example.fr", "SIGNUP");
        assertThat(session.get("token").asText()).isNotBlank(); assertThat(session.get("recoveryCodes")).hasSize(10);
        assertThat(roles.findAll()).singleElement().satisfies(r -> assertThat(r.getStatus()).isEqualTo(RoleChangeRequest.Status.PENDING));
        assertThat(recovery.findAll()).allSatisfy(r -> assertThat(r.getCodeHash()).hasSize(64));
        send("/api/auth/verify", null, Map.of("challengeId", challenge.get("challengeId").asText(), "code", code("alice@example.fr", "SIGNUP"))).andExpect(status().isBadRequest());
    }
    @Test void passwordStepDoesNotIssueJwtUntilOtpAndMfaCodesAreSingleUse() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true);
        var c = login("ALICE@example.fr", PASSWORD); assertThat(c.get("token").isNull()).isTrue();
        var session = verifyChallenge(c, "alice@example.fr", "MFA_LOGIN");
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + session.get("token").asText())).andExpect(status().isOk());
        send("/api/auth/verify", null, Map.of("challengeId", c.get("challengeId").asText(), "code", code("alice@example.fr", "MFA_LOGIN"))).andExpect(status().isBadRequest());
        assertThat(a.codes()).hasSize(10);
    }
    @Test void fiveWrongGuessesPersistAcrossRequestsAndLockTheChallenge() throws Exception {
        account("alice@example.fr", Role.USER, true); var c = login("alice@example.fr", PASSWORD);
        String id = c.get("challengeId").asText(), actual = code("alice@example.fr", "MFA_LOGIN");
        for (int attempt = 1; attempt <= 5; attempt++) {
            send("/api/auth/verify", null, Map.of("challengeId", id, "code", wrong(actual))).andExpect(status().isBadRequest());
            assertThat(challenges.findById(id).orElseThrow().getAttempts()).isEqualTo(attempt);
        }
        send("/api/auth/verify", null, Map.of("challengeId", id, "code", actual)).andExpect(status().isBadRequest());
    }
    @Test void expiredAndWrongPurposeChallengesCannotAuthenticate() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true); var c = login("alice@example.fr", PASSWORD);
        var stored = challenges.findById(c.get("challengeId").asText()).orElseThrow(); stored.setExpiresAt(Instant.now().minusSeconds(1)); challenges.save(stored);
        send("/api/auth/verify", null, Map.of("challengeId", stored.getId(), "code", code("alice@example.fr", "MFA_LOGIN"))).andExpect(status().isBadRequest());
        var security = postJson("/api/security/challenge", a.token(), Map.of("action", "RECOVERY_ROTATE", "currentPassword", PASSWORD), 200);
        send("/api/auth/verify", null, Map.of("challengeId", security.get("challengeId").asText(), "code", code("alice@example.fr", "RECOVERY_ROTATE"))).andExpect(status().isBadRequest());
    }
    @Test void recoveryCodeIsConsumedAtomicallyAndCannotBeReusedOnNewChallenge() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true); var c = login("alice@example.fr", PASSWORD);
        postJson("/api/auth/mfa/recover", null, Map.of("challengeId", c.get("challengeId").asText(), "code", a.codes().getFirst()), 200);
        age("alice@example.fr", EmailChallenge.Purpose.MFA_LOGIN); var next = login("alice@example.fr", PASSWORD);
        send("/api/auth/mfa/recover", null, Map.of("challengeId", next.get("challengeId").asText(), "code", a.codes().getFirst())).andExpect(status().isBadRequest());
        assertThat(recovery.countByUserIdAndUsedAtIsNull(a.user().getId())).isEqualTo(9);
    }
    @Test void passwordlessCannotBypassMfaAndConsumesARecoveryCode() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true);
        var c = postJson("/api/auth/passwordless/request", null, Map.of("email", "alice@example.fr"), 200);
        var proof = new HashMap<String, Object>(Map.of("challengeId", c.get("challengeId").asText(), "code", code("alice@example.fr", "PASSWORDLESS")));
        send("/api/auth/verify", null, proof).andExpect(status().isBadRequest()).andExpect(jsonPath("message").value("PASSWORDLESS_RECOVERY_REQUIRED"));
        proof.put("recoveryCode", a.codes().getFirst()); postJson("/api/auth/verify", null, proof, 200);
        assertThat(recovery.countByUserIdAndUsedAtIsNull(a.user().getId())).isEqualTo(9);
    }
    @Test void passwordlessWorksWithoutPasswordForAccountsWithoutMfaAndMasksUnknownEmails() throws Exception {
        account("alice@example.fr", Role.USER, false);
        var known = postJson("/api/auth/passwordless/request", null, Map.of("email", "alice@example.fr"), 200);
        var unknown = postJson("/api/auth/passwordless/request", null, Map.of("email", "missing@example.fr"), 200);
        assertThat(known.fieldNames()).toIterable().containsExactlyElementsOf(() -> unknown.fieldNames());
        assertThat(unknown.get("token").isNull()).isTrue();
        verifyChallenge(known, "alice@example.fr", "PASSWORDLESS");
        send("/api/auth/verify", null, Map.of("challengeId", unknown.get("challengeId").asText(), "code", "123456")).andExpect(status().isBadRequest());
    }
    @Test void resendingRespectsCooldownAndInvalidatesEarlierChallenge() throws Exception {
        account("alice@example.fr", Role.USER, true); var c = login("alice@example.fr", PASSWORD);
        String oldId = c.get("challengeId").asText();
        send("/api/auth/challenges/"+oldId+"/resend", null, Map.of()).andExpect(status().isTooManyRequests());
        age("alice@example.fr", EmailChallenge.Purpose.MFA_LOGIN);
        var next = postJson("/api/auth/challenges/"+oldId+"/resend", null, Map.of(), 200);
        send("/api/auth/verify", null, Map.of("challengeId", oldId, "code", code("alice@example.fr", "MFA_LOGIN"))).andExpect(status().isBadRequest());
        verifyChallenge(next, "alice@example.fr", "MFA_LOGIN");
    }
    @Test void recoveryRotationRequiresPasswordAndEmailAndRevokesOldCodesAndSessions() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true);
        send("/api/security/challenge", a.token(), Map.of("action", "RECOVERY_ROTATE", "currentPassword", "wrong")).andExpect(status().isBadRequest());
        var c = postJson("/api/security/challenge", a.token(), Map.of("action", "RECOVERY_ROTATE", "currentPassword", PASSWORD), 200);
        var session = postJson("/api/security/confirm", a.token(), Map.of("challengeId", c.get("challengeId").asText(), "code", code("alice@example.fr", "RECOVERY_ROTATE")), 200);
        assertThat(session.get("recoveryCodes")).hasSize(10);
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+a.token())).andExpect(status().isUnauthorized());
        var login = login("alice@example.fr", PASSWORD);
        send("/api/auth/mfa/recover", null, Map.of("challengeId", login.get("challengeId").asText(), "code", a.codes().getFirst())).andExpect(status().isBadRequest());
    }
    @Test void emailAndIdentifierDuplicatesAreRejectedIgnoringCase() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false); a.user().setUsername("alice.unique"); users.save(a.user());
        send("/api/auth/register", null, registration("ALICE@example.fr")).andExpect(status().isConflict());
        var body = registration("another@example.fr"); body.put("username", "ALICE.UNIQUE");
        send("/api/auth/register", null, body).andExpect(status().isConflict());
        assertThat(login("ALICE.UNIQUE", PASSWORD).get("token").asText()).isNotBlank();
    }
    @Test void requestedRoleNeedsVerifiedAccountAndIndependentApproval() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false), admin = account("admin@example.fr", Role.ADMIN, false);
        var request = postJson("/api/security/role-requests", a.token(), Map.of("requestedRole", "DOCTOR", "reason", "Professional role requested"), 200);
        send("/api/security/role-requests", a.token(), Map.of("requestedRole", "ADMIN", "reason", "Cannot have two pending requests")).andExpect(status().isConflict());
        mvc.perform(get("/api/security/admin/role-requests").header("Authorization", "Bearer "+a.token())).andExpect(status().isForbidden());
        String path = "/api/security/admin/role-requests/"+request.get("id").asLong()+"/decision";
        postJson(path, admin.token(), Map.of("approve", true, "note", "Professional qualifications checked"), 200);
        assertThat(users.findById(a.user().getId()).orElseThrow().getRole()).isEqualTo(Role.DOCTOR);
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+a.token())).andExpect(status().isUnauthorized());
        send(path, admin.token(), Map.of("approve", true, "note", "Cannot review this request twice")).andExpect(status().isConflict());
        assertThat(audit.findAll()).anySatisfy(e -> { assertThat(e.getAction()).isEqualTo("ROLE_APPROVED"); assertThat(e.getActorId()).isEqualTo(admin.user().getId()); });
    }
    @Test void rolesCannotBeSelfApprovedOrChangedThroughLegacyEndpoint() throws Exception {
        Account admin = account("admin@example.fr", Role.ADMIN, false);
        var r = postJson("/api/security/role-requests", admin.token(), Map.of("requestedRole", "DOCTOR", "reason", "A different role is requested"), 200);
        send("/api/security/admin/role-requests/"+r.get("id").asLong()+"/decision", admin.token(), Map.of("approve", true, "note", "Cannot approve my own request")).andExpect(status().isForbidden());
        mvc.perform(patch("/api/users/"+admin.user().getId()+"/role").header("Authorization", "Bearer "+admin.token()).contentType(MediaType.APPLICATION_JSON).content("{\"role\":\"USER\"}"))
                .andExpect(status().isConflict());
    }
    @Test void rejectingRoleRequestPreservesRoleAndRecordsDecision() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false), admin = account("admin@example.fr", Role.ADMIN, false);
        var r = postJson("/api/security/role-requests", a.token(), Map.of("requestedRole", "DOCTOR", "reason", "Professional role requested"), 200);
        postJson("/api/security/admin/role-requests/"+r.get("id").asLong()+"/decision", admin.token(), Map.of("approve", false, "note", "Professional evidence is insufficient"), 200);
        assertThat(users.findById(a.user().getId()).orElseThrow().getRole()).isEqualTo(Role.USER);
        assertThat(roles.findAll()).singleElement().satisfies(v -> { assertThat(v.getStatus()).isEqualTo(RoleChangeRequest.Status.REJECTED); assertThat(v.getDecisionNote()).contains("insufficient"); });
    }
    @Test void passwordHistoryRejectsReuseAndChangeReturnsFreshSession() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false);
        var response = mvc.perform(put("/api/users/me/password").header("Authorization", "Bearer "+a.token()).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("currentPassword", PASSWORD, "newPassword", "DifferentPassword456!"))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String token = json.readTree(response).get("token").asText();
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+a.token())).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/users/me/password").header("Authorization", "Bearer "+token).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("currentPassword", "DifferentPassword456!", "newPassword", PASSWORD))))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("message").value("PASSWORD_REUSED"));
        assertThat(history.findAll()).singleElement().satisfies(h -> assertThat(h.getPasswordHash()).startsWith("$2"));
    }
    @Test void compromisedPasswordAndUnavailableScreeningFailBeforeAccountCreation() throws Exception {
        doThrow(new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_COMPROMISED")).when(checker).rejectCompromised(PASSWORD);
        send("/api/auth/register", null, registration("alice@example.fr")).andExpect(status().isBadRequest()).andExpect(jsonPath("message").value("PASSWORD_COMPROMISED"));
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "PASSWORD_SCREENING_UNAVAILABLE")).when(checker).rejectCompromised(PASSWORD);
        send("/api/auth/register", null, registration("alice@example.fr")).andExpect(status().isServiceUnavailable());
        assertThat(users.count()).isZero();
    }
    @Test void confirmedIncidentBlocksPasswordAndPasswordlessAndResetClearsFlag() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true), admin = account("admin@example.fr", Role.ADMIN, false);
        postJson("/api/security/admin/users/"+a.user().getId()+"/incident", admin.token(), Map.of("reason", "Confirmed credential theft incident"), 200);
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+a.token())).andExpect(status().isUnauthorized());
        send("/api/auth/login", null, Map.of("identifier", "alice@example.fr", "password", PASSWORD)).andExpect(status().isLocked());
        var c = postJson("/api/auth/passwordless/request", null, Map.of("email", "alice@example.fr"), 200);
        send("/api/auth/verify", null, Map.of("challengeId", c.get("challengeId").asText(), "code", code("alice@example.fr", "PASSWORDLESS"), "recoveryCode", a.codes().getFirst())).andExpect(status().isLocked());
        assertThat(recovery.countByUserIdAndUsedAtIsNull(a.user().getId())).isZero();
        String code = resetCode("alice@example.fr");
        postJson("/api/auth/reset-password", null, Map.of("email", "alice@example.fr", "code", code, "newPassword", "AfterIncidentPassword123!"), 200);
        assertThat(users.findById(a.user().getId()).orElseThrow().isPasswordResetRequired()).isFalse();
        verifyChallenge(login("alice@example.fr", "AfterIncidentPassword123!"), "alice@example.fr", "MFA_LOGIN");
    }
    @Test void resetCodeIsHashedSingleUseAndWrongAttemptsAreCommitted() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false); String actual = resetCode("alice@example.fr");
        assertThat(users.findById(a.user().getId()).orElseThrow().getResetCodeHash()).isNotEqualTo(actual);
        for (int i=1; i<=5; i++) {
            send("/api/auth/reset-password", null, Map.of("email", "alice@example.fr", "code", wrong(actual), "newPassword", "NewPassword123!"))
                    .andExpect(status().isBadRequest());
            assertThat(users.findById(a.user().getId()).orElseThrow().getResetCodeAttempts()).isEqualTo(i);
        }
        send("/api/auth/reset-password", null, Map.of("email", "alice@example.fr", "code", actual, "newPassword", "NewPassword123!"))
                .andExpect(status().isBadRequest());
    }
    @Test void resetRequestMasksUnknownEmailAndMailFailureRollsBackCode() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false);
        var known = postJson("/api/auth/forgot-password", null, Map.of("email", "alice@example.fr"), 200);
        var unknown = postJson("/api/auth/forgot-password", null, Map.of("email", "unknown@example.fr"), 200);
        assertThat(known).isEqualTo(unknown);
        var user = users.findById(a.user().getId()).orElseThrow(); user.setResetCodeRequestedAt(Instant.now().minusSeconds(61)); user.setResetCodeHash(null); users.save(user);
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "Mail unavailable")).when(mail).sendCode(anyString(), anyString());
        send("/api/auth/forgot-password", null, Map.of("email", "alice@example.fr")).andExpect(status().isServiceUnavailable());
        assertThat(users.findById(a.user().getId()).orElseThrow().getResetCodeHash()).isNull();
    }
    @Test void mergeRequiresBothProofsExplicitConflictsAndIndependentReviewThenPreservesMedicalRecords() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true), b = account("second@example.fr", Role.USER, false), admin = account("admin@example.fr", Role.ADMIN, false);
        b.user().setFullName("Alice Different Name"); b.user().setPassword(encoder.encode("SecondaryPassword456!")); users.save(b.user());
        appointments.save(Appointment.builder().user(b.user()).doctorName("Dr Example").dateTime(LocalDateTime.now().plusDays(1)).build());
        var r = postJson("/api/security/merges", a.token(), Map.of("targetEmail", "second@example.fr", "reason", "Both accounts belong to the same person"), 200);
        String path = "/api/security/admin/merges/"+r.get("id").asText()+"/decision";
        send(path, admin.token(), Map.of("approve", true, "note", "Cannot approve without ownership proofs")).andExpect(status().isConflict());
        String primary = code("alice@example.fr", "MERGE_PRIMARY"), secondary = code("second@example.fr", "MERGE_SECONDARY");
        send("/api/security/merges/"+r.get("id").asText()+"/verify", a.token(), Map.of("primaryCode", primary, "secondaryCode", wrong(secondary))).andExpect(status().isBadRequest());
        postJson("/api/security/merges/"+r.get("id").asText()+"/verify", a.token(), Map.of("primaryCode", primary, "secondaryCode", secondary), 200);
        assertThat(users.findById(b.user().getId()).orElseThrow().getMergedIntoId()).isNull();
        send(path, admin.token(), Map.of("approve", true, "note", "Resolve all conflicts explicitly")).andExpect(status().isConflict()).andExpect(jsonPath("message").value("MERGE_CONFLICTS_UNRESOLVED"));
        postJson(path, admin.token(), Map.of("approve", true, "note", "Both identities and conflicts reviewed", "fieldSources", Map.of("fullName", "PRIMARY")), 200);
        assertThat(users.findById(b.user().getId()).orElseThrow().getMergedIntoId()).isEqualTo(a.user().getId());
        assertThat(appointments.findByUserIdOrderByDateTimeDesc(a.user().getId())).hasSize(1);
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+a.token())).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer "+b.token())).andExpect(status().isUnauthorized());
        send("/api/auth/login", null, Map.of("identifier", "second@example.fr", "password", "SecondaryPassword456!")).andExpect(status().isUnauthorized());
        verifyChallenge(login("second@example.fr", PASSWORD), "alice@example.fr", "MFA_LOGIN");
        assertThat(audit.findAll()).anySatisfy(e -> assertThat(e.getAction()).isEqualTo("ACCOUNTS_MERGED"));
    }
    @Test void privilegedAccountsCannotBeMergedAndUnprovenProfilesAreNotDisclosed() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false), b = account("doctor@example.fr", Role.DOCTOR, false), admin = account("admin@example.fr", Role.ADMIN, false);
        var r = postJson("/api/security/merges", a.token(), Map.of("targetEmail", "doctor@example.fr", "reason", "Request requires special role handling"), 200);
        assertThat(r.get("secondaryProfile").size()).isZero(); assertThat(r.get("secondaryUserId").isNull()).isTrue();
        postJson("/api/security/merges/"+r.get("id").asText()+"/verify", a.token(), Map.of("primaryCode", code("alice@example.fr", "MERGE_PRIMARY"), "secondaryCode", code("doctor@example.fr", "MERGE_SECONDARY")), 200);
        send("/api/security/admin/merges/"+r.get("id").asText()+"/decision", admin.token(), Map.of("approve", true, "note", "Professional privileges cannot be combined")).andExpect(status().isConflict());
        assertThat(users.findById(b.user().getId()).orElseThrow().getMergedIntoId()).isNull();
    }
    @Test void changedCredentialsInvalidateMergeProofAndOrdinaryUsersCannotInspectAdminData() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false), b = account("second@example.fr", Role.USER, false), admin = account("admin@example.fr", Role.ADMIN, false);
        var r = postJson("/api/security/merges", a.token(), Map.of("targetEmail", "second@example.fr", "reason", "Both accounts belong to the same person"), 200);
        postJson("/api/security/merges/"+r.get("id").asText()+"/verify", a.token(), Map.of("primaryCode", code("alice@example.fr", "MERGE_PRIMARY"), "secondaryCode", code("second@example.fr", "MERGE_SECONDARY")), 200);
        var secondary = users.findById(b.user().getId()).orElseThrow(); AccountAccess.revoke(secondary); users.save(secondary);
        send("/api/security/admin/merges/"+r.get("id").asText()+"/decision", admin.token(), Map.of("approve", true, "note", "Proof is stale after credentials change")).andExpect(status().isConflict());
        for (String path : List.of("/api/security/admin/duplicates", "/api/security/admin/audit", "/api/security/admin/merges"))
            mvc.perform(get(path).header("Authorization", "Bearer "+a.token())).andExpect(status().isForbidden());
    }
    @Test void profileEditsCannotReplaceAuthenticationEmailOrRedirectOtp() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true);
        mvc.perform(put("/api/users/me").header("Authorization", "Bearer "+a.token()).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("fullName", "Alice Martin", "email", "replacement@example.fr"))))
                .andExpect(status().isConflict()).andExpect(jsonPath("message").value("EMAIL_CHANGE_REQUIRES_VERIFICATION"));
        assertThat(users.findById(a.user().getId()).orElseThrow().getEmail()).isEqualTo("alice@example.fr");
    }
    @Test void concurrentOtpVerificationsIssueOnlyOneSession() throws Exception {
        account("alice@example.fr", Role.USER, true);
        var challenge = login("alice@example.fr", PASSWORD);
        Map<String, String> body = Map.of("challengeId", challenge.get("challengeId").asText(), "code", code("alice@example.fr", "MFA_LOGIN"));
        var executor = java.util.concurrent.Executors.newFixedThreadPool(2);
        var start = new java.util.concurrent.CountDownLatch(1);
        try {
            java.util.concurrent.Callable<Integer> verify = () -> { start.await(); return send("/api/auth/verify", null, body).andReturn().getResponse().getStatus(); };
            var first = executor.submit(verify); var second = executor.submit(verify); start.countDown();
            assertThat(List.of(first.get(10, java.util.concurrent.TimeUnit.SECONDS), second.get(10, java.util.concurrent.TimeUnit.SECONDS))).containsExactlyInAnyOrder(200, 400);
        } finally { executor.shutdownNow(); }
    }
    @Test void medicalResponsesNeverExposeAuthenticationSecrets() throws Exception {
        Account a = account("alice@example.fr", Role.USER, false);
        User u = users.findById(a.user().getId()).orElseThrow();
        u.setTokenVersion(0L); u.setResetCodeHash("private-reset-code-hash"); u.setResetCodeAttempts(3);
        u.setResetCodeExpiresAt(Instant.now().plusSeconds(600)); users.save(u);
        appointments.save(Appointment.builder().user(u).doctorName("Dr Example").dateTime(LocalDateTime.now().plusDays(1)).build());
        mvc.perform(get("/api/appointments").header("Authorization", "Bearer "+a.token()))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].user.email").value("alice@example.fr"))
                .andExpect(jsonPath("$[0].user.password").doesNotExist())
                .andExpect(jsonPath("$[0].user.tokenVersion").doesNotExist())
                .andExpect(jsonPath("$[0].user.resetCodeHash").doesNotExist())
                .andExpect(jsonPath("$[0].user.resetCodeExpiresAt").doesNotExist())
                .andExpect(jsonPath("$[0].user.resetCodeAttempts").doesNotExist());
    }
    @Test void verifiedGmailVariantsAreSuggestedWithoutAutomaticallyMerging() throws Exception {
        Account a = account("alice.martin@gmail.com", Role.USER, false);
        Account b = account("alicemartin+health@gmail.com", Role.USER, false);
        Account admin = account("admin@example.fr", Role.ADMIN, false);
        String response = mvc.perform(get("/api/security/admin/duplicates").header("Authorization", "Bearer "+admin.token()))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        assertThat(json.readTree(response)).hasSize(1);
        assertThat(json.readTree(response).get(0).get("reason").asText()).contains("Gmail");
        assertThat(users.findById(a.user().getId()).orElseThrow().getMergedIntoId()).isNull();
        assertThat(users.findById(b.user().getId()).orElseThrow().getMergedIntoId()).isNull();
    }
    @Test void unverifiedAliasesAndOrganizationDomainsAreNotUsedAsIdentityEvidence() throws Exception {
        account("alice.martin@gmail.com", Role.USER, false);
        Account pending = account("alicemartin+work@gmail.com", Role.USER, false);
        pending.user().setEmailVerified(false); users.save(pending.user());
        account("alice.martin@example.fr", Role.USER, false); account("alicemartin@example.fr", Role.USER, false);
        Account admin = account("admin@example.fr", Role.ADMIN, false);
        mvc.perform(get("/api/security/admin/duplicates").header("Authorization", "Bearer "+admin.token()))
                .andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
    }
    @Test void backupLoginWorksWhenSmtpIsUnavailableAndStillRequiresPasswordAndUnusedCode() throws Exception {
        Account a = account("alice@example.fr", Role.USER, true);
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "Mail unavailable")).when(mail).ensureAvailable();
        send("/api/auth/login", null, Map.of("identifier", "alice@example.fr", "password", PASSWORD)).andExpect(status().isServiceUnavailable());
        send("/api/auth/login/recovery", null, Map.of("identifier", "alice@example.fr", "password", "wrong", "code", a.codes().getFirst())).andExpect(status().isUnauthorized());
        assertThat(recovery.countByUserIdAndUsedAtIsNull(a.user().getId())).isEqualTo(10);
        var body = Map.of("identifier", "alice@example.fr", "password", PASSWORD, "code", a.codes().getFirst());
        postJson("/api/auth/login/recovery", null, body, 200);
        send("/api/auth/login/recovery", null, body).andExpect(status().isBadRequest());
        assertThat(recovery.countByUserIdAndUsedAtIsNull(a.user().getId())).isEqualTo(9);
    }
}
