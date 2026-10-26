package com.medicare.user.dto;

import com.medicare.user.entity.Role;
import com.medicare.user.entity.User;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public final class UserDtos {
    private UserDtos() {}

    public record UserResponse(
            Long id,
            String fullName,
            String email,
            String phoneNumber,
            LocalDate birthDate,
            String bio,
            String profilePhotoUrl,
            Role role,
            String username,
            boolean emailVerified,
            boolean mfaEnabled,
            boolean passwordResetRequired
    ) {
        public static UserResponse from(User user) {
            return new UserResponse(
                    user.getId(),
                    user.getFullName(),
                    user.getEmail(),
                    user.getPhoneNumber(),
                    user.getBirthDate(),
                    user.getBio(),
                    user.getProfilePhotoUrl(),
                    user.getRole(), user.getUsername(), user.isEmailVerified(),
                    user.isMfaEnabled(), user.isPasswordResetRequired());
        }
    }

    public record UpdateProfileRequest(
            @NotBlank @Size(max = 120) String fullName,
            @Email @NotBlank @Size(max = 160) String email,
            @Size(max = 30) String phoneNumber,
            LocalDate birthDate,
            @Size(max = 500) String bio,
            @Size(max = 500) String profilePhotoUrl
    ) {}

    public record ChangePasswordRequest(
            @NotBlank String currentPassword,
            @NotBlank @Size(min = 6, max = 100) String newPassword
    ) {}

    public record UpdateRoleRequest(@NotNull Role role) {}
}
