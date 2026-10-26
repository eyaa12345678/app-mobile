package com.medicare.auth.dto;
import com.medicare.user.dto.UserDtos;
import com.medicare.user.entity.Role;
import com.medicare.security.account.EmailChallenge;
import jakarta.validation.constraints.*;
import java.util.List;
public final class AuthDtos {
    private AuthDtos() {}
    public record RegisterRequest(
            @NotBlank @Size(max = 120) String fullName,
            @Email @NotBlank @Size(max = 160) String email,
            @NotBlank @Size(min = 12, max = 100) String password,
            @Pattern(regexp = "[a-zA-Z0-9._-]{3,40}") String username,
            Role requestedRole) {}
    public record LoginRequest(@Email @Size(max = 160) String email, @Size(max = 160) String identifier, @NotBlank String password) {}
    public record RecoveryLoginRequest(@NotBlank @Size(max = 160) String identifier, @NotBlank @Size(max = 100) String password, @NotBlank @Size(max = 64) String code) {}
    public record ForgotPasswordRequest(@Email @NotBlank @Size(max = 160) String email) {}
    public record VerifyRequest(@NotBlank @Size(max = 36) String challengeId, @NotBlank @Size(max = 64) String code, @Size(max = 64) String recoveryCode) {}
    public record ResetPasswordRequest(@Email @NotBlank @Size(max = 160) String email,
            @NotBlank @Pattern(regexp = "[0-9]{6}") String code, @NotBlank @Size(min = 12, max = 100) String newPassword) {}
    public record AuthResponse(String token, String tokenType, long expiresInMs, UserDtos.UserResponse user,
                               String challengeId, String challengeType, long expiresInSeconds, List<String> recoveryCodes) {
        public static AuthResponse challenge(EmailChallenge c) { return anonymousChallenge(c.getId(), c.getPurpose().name()); }
        public static AuthResponse anonymousChallenge(String id, String purpose) {
            return new AuthResponse(null, null, 0, null, id, purpose, 600, List.of());
        }
    }
    public record MessageResponse(String message) {}
}
