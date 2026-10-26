package com.medicare.auth.service;

import com.medicare.common.ApiException;
import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Duration;
import java.util.HexFormat;
import org.springframework.beans.factory.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class CompromisedPasswordChecker {
    private final boolean enabled;
    private final HttpClient client;
    @Autowired
    public CompromisedPasswordChecker(@Value("${app.security.compromised-password-check:true}") boolean enabled) {
        this(enabled, HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(4)).build());
    }
    public CompromisedPasswordChecker(boolean enabled, HttpClient client) { this.enabled = enabled; this.client = client; }
    public boolean isEnabled() { return enabled; }
    public boolean isCompromised(String password) {
        if (!enabled) return false;
        try {
            String hash = HexFormat.of().withUpperCase().formatHex(MessageDigest.getInstance("SHA-1")
                    .digest(password.getBytes(StandardCharsets.UTF_8)));
            HttpRequest request = HttpRequest.newBuilder(URI.create("https://api.pwnedpasswords.com/range/" + hash.substring(0, 5)))
                    .timeout(Duration.ofSeconds(5)).header("Add-Padding", "true").header("User-Agent", "MediCare-Password-Screening").GET().build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (response.statusCode() != 200) throw unavailable();
            boolean hasValidRow = false;
            for (String line : response.body().split("\\R")) {
                if (line.isBlank()) continue;
                String[] row = line.trim().split(":", 2);
                if (row.length != 2 || !row[0].matches("[A-Fa-f0-9]{35}") || !row[1].matches("[0-9]+")) throw unavailable();
                hasValidRow = true;
                if (row[0].equalsIgnoreCase(hash.substring(5)) && Long.parseLong(row[1]) > 0) return true;
            }
            if (!hasValidRow) throw unavailable();
            return false;
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt(); throw unavailable();
        } catch (java.io.IOException | NoSuchAlgorithmException | NumberFormatException ex) { throw unavailable(); }
    }
    public void rejectCompromised(String password) {
        if (isCompromised(password)) throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_COMPROMISED");
    }
    private ApiException unavailable() { return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "PASSWORD_SCREENING_UNAVAILABLE"); }
}
