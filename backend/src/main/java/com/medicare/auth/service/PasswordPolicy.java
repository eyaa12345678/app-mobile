package com.medicare.auth.service;

import com.medicare.common.ApiException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpStatus;

public final class PasswordPolicy {
    private PasswordPolicy() {}

    public static void validate(String password) {
        // BCrypt accepts at most 72 bytes, which can be fewer than 72 Unicode characters.
        if (password == null || password.isBlank() || password.length() < 12
                || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_POLICY_VIOLATION");
        }
    }
}
