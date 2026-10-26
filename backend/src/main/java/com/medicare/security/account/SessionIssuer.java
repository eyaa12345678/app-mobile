package com.medicare.security.account;
import com.medicare.auth.dto.AuthDtos;
import com.medicare.security.JwtService;
import com.medicare.user.dto.UserDtos;
import com.medicare.user.entity.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
@Service @RequiredArgsConstructor
public class SessionIssuer {
    private final JwtService jwt;
    public AuthDtos.AuthResponse issue(User user) { return issue(user, List.of()); }
    public AuthDtos.AuthResponse issue(User user, List<String> codes) {
        return new AuthDtos.AuthResponse(jwt.generateToken(user), "Bearer", jwt.getExpirationMs(), UserDtos.UserResponse.from(user), null, null, 0, codes);
    }
}
