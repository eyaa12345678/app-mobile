package com.medicare.user.service;

import com.medicare.common.ApiException;
import com.medicare.auth.service.PasswordPolicy;
import com.medicare.security.account.*;
import com.medicare.auth.dto.AuthDtos;
import com.medicare.user.dto.UserDtos;
import com.medicare.user.entity.User;
import com.medicare.user.repository.UserRepository;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordLifecycle passwords;
    private final AccountAccess accounts;
    private final SessionIssuer sessions;

    @Transactional(readOnly = true)
    public UserDtos.UserResponse currentProfile(Authentication authentication) {
        return UserDtos.UserResponse.from(currentUser(authentication));
    }

    @Transactional
    public UserDtos.UserResponse updateProfile(
            Authentication authentication,
            UserDtos.UpdateProfileRequest request) {
        User user = accounts.lock(currentUser(authentication).getId());
        String email = normalizeEmail(request.email());
        if (!user.getEmail().equals(email) && userRepository.existsByEmailIgnoreCaseAndIdNot(email, user.getId())) {
            throw new ApiException(HttpStatus.CONFLICT, "Email already exists");
        }

        if (!user.getEmail().equals(email)) {
            // A profile edit must never replace the contact that receives all authentication codes.
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_CHANGE_REQUIRES_VERIFICATION");
        }

        user.setFullName(request.fullName().trim());
        user.setEmail(email);
        user.setPhoneNumber(trimToNull(request.phoneNumber()));
        user.setBirthDate(request.birthDate());
        user.setBio(trimToNull(request.bio()));
        user.setProfilePhotoUrl(trimToNull(request.profilePhotoUrl()));
        return UserDtos.UserResponse.from(userRepository.save(user));
    }

    @Transactional
    public AuthDtos.AuthResponse changePassword(Authentication authentication, UserDtos.ChangePasswordRequest request) {
        PasswordPolicy.validate(request.newPassword());
        User user = accounts.lock(currentUser(authentication).getId());
        if (!passwordEncoder.matches(request.currentPassword(), user.getPassword())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Current password is incorrect");
        }
        passwords.replace(user, request.newPassword());
        userRepository.save(user);
        return sessions.issue(user);
    }

    @Transactional(readOnly = true)
    public List<UserDtos.UserResponse> findAll() {
        return userRepository.findAll().stream()
                .filter(user -> user.getMergedIntoId() == null)
                .map(UserDtos.UserResponse::from)
                .toList();
    }

    @Transactional
    public UserDtos.UserResponse updateRole(Long id, UserDtos.UpdateRoleRequest request) {
        throw new ApiException(HttpStatus.CONFLICT, "USE_ROLE_REQUEST_WORKFLOW");
    }

    private User currentUser(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return userRepository.findByEmailIgnoreCase(authentication.getName())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required"));
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
