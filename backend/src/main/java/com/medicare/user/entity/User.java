package com.medicare.user.entity;

import jakarta.persistence.*;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.time.LocalDate;
import java.time.Instant;
import lombok.*;

@Entity
@JsonIgnoreProperties({"password", "tokenVersion", "resetCodeHash", "resetCodeExpiresAt", "resetCodeRequestedAt", "resetCodeAttempts"})
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String fullName;

    @Column(nullable = false, unique = true, length = 160)
    private String email;

    @Column(nullable = false)
    private String password;

    @Column(unique = true, length = 40)
    private String username;

    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean emailVerified;
    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean mfaEnabled;
    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean passwordResetRequired;
    private Long mergedIntoId;

    // Nullable for existing accounts; a missing version is treated as zero.
    private Long tokenVersion;

    private String resetCodeHash;
    private Instant resetCodeExpiresAt;
    private Instant resetCodeRequestedAt;
    @Column(nullable = false, columnDefinition = "integer default 0")
    private int resetCodeAttempts;

    @Column(length = 30)
    private String phoneNumber;

    private LocalDate birthDate;

    @Column(length = 500)
    private String bio;

    @Column(length = 500)
    private String profilePhotoUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private Role role = Role.USER;
}
