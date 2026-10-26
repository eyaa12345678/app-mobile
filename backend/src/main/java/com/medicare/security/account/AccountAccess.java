package com.medicare.security.account;
import com.medicare.common.ApiException;
import com.medicare.user.entity.*;
import com.medicare.user.repository.UserRepository;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class AccountAccess {
    private final UserRepository users;
    @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entities;
    public User current(Authentication authentication) {
        if (authentication == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        User user = users.findByEmailIgnoreCase(authentication.getName())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required"));
        if (user.getMergedIntoId() != null || user.isPasswordResetRequired()) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Authentication required");
        }
        return user;
    }
    public User admin(Authentication authentication) {
        User user = current(authentication);
        if (user.getRole() != Role.ADMIN) throw new ApiException(HttpStatus.FORBIDDEN, "Access denied");
        if (!user.isEmailVerified()) throw new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED");
        return user;
    }
    public Optional<User> resolve(String identifier) {
        if (identifier == null || identifier.isBlank()) return Optional.empty();
        String value = identifier.trim().toLowerCase(Locale.ROOT);
        Optional<User> result = value.contains("@") ? users.findByEmailIgnoreCase(value) : users.findByUsernameIgnoreCase(value);
        Set<Long> visited = new HashSet<>();
        while (result.isPresent() && result.get().getMergedIntoId() != null) {
            if (!visited.add(result.get().getId())) return Optional.empty();
            result = users.findById(result.get().getMergedIntoId());
        }
        return result;
    }
    public User lock(Long id) {
        User user = users.findByIdForUpdate(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Account not found"));
        entities.refresh(user, jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        return user;
    }
    public static long version(User user) { return user.getTokenVersion() == null ? 0L : user.getTokenVersion(); }
    public static void revoke(User user) { user.setTokenVersion(version(user) + 1); }
}
