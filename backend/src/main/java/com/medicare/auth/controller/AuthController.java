package com.medicare.auth.controller;

import com.medicare.auth.dto.AuthDtos;
import com.medicare.auth.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthDtos.AuthResponse register(@Valid @RequestBody AuthDtos.RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthDtos.AuthResponse login(@Valid @RequestBody AuthDtos.LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/login/recovery")
    public AuthDtos.AuthResponse recoveryLogin(@Valid @RequestBody AuthDtos.RecoveryLoginRequest request) {
        return authService.recoveryLogin(request);
    }

    @PostMapping("/passwordless/request")
    public AuthDtos.AuthResponse passwordless(@Valid @RequestBody AuthDtos.ForgotPasswordRequest request) {
        return authService.passwordless(request);
    }

    @PostMapping("/challenges/{id}/resend")
    public AuthDtos.AuthResponse resend(@PathVariable String id) { return authService.resend(id); }

    @PostMapping("/verify")
    public AuthDtos.AuthResponse verify(@Valid @RequestBody AuthDtos.VerifyRequest request) { return authService.verify(request); }

    @PostMapping("/mfa/recover")
    public AuthDtos.AuthResponse recover(@Valid @RequestBody AuthDtos.VerifyRequest request) { return authService.recover(request); }

    @PostMapping("/forgot-password")
    public AuthDtos.MessageResponse forgotPassword(@Valid @RequestBody AuthDtos.ForgotPasswordRequest request) {
        return authService.forgotPassword(request);
    }

    @PostMapping("/logout")
    public AuthDtos.MessageResponse logout() {
        return authService.logout();
    }

    @PostMapping("/reset-password")
    public AuthDtos.MessageResponse resetPassword(@Valid @RequestBody AuthDtos.ResetPasswordRequest request) {
        return authService.resetPassword(request);
    }
}
