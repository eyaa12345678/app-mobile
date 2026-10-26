package com.medicare.user.controller;

import com.medicare.auth.dto.AuthDtos;
import com.medicare.user.dto.UserDtos;
import com.medicare.user.service.UserService;
import com.medicare.security.account.AccountAccess;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;
    private final AccountAccess accounts;

    @GetMapping("/me")
    public UserDtos.UserResponse me(Authentication authentication) {
        return userService.currentProfile(authentication);
    }

    @PutMapping("/me")
    public UserDtos.UserResponse updateMe(
            @Valid @RequestBody UserDtos.UpdateProfileRequest request,
            Authentication authentication) {
        return userService.updateProfile(authentication, request);
    }

    @PutMapping("/me/password")
    public AuthDtos.AuthResponse changePassword(
            @Valid @RequestBody UserDtos.ChangePasswordRequest request,
            Authentication authentication) {
        return userService.changePassword(authentication, request);
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public List<UserDtos.UserResponse> allUsers(Authentication authentication) {
        accounts.admin(authentication);
        return userService.findAll();
    }

    @PatchMapping("/{id}/role")
    @PreAuthorize("hasRole('ADMIN')")
    public UserDtos.UserResponse updateRole(
            @PathVariable Long id,
            @Valid @RequestBody UserDtos.UpdateRoleRequest request) {
        return userService.updateRole(id, request);
    }
}
