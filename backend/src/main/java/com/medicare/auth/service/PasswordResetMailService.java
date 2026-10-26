package com.medicare.auth.service;

import com.medicare.common.ApiException;
import jakarta.mail.AuthenticationFailedException;
import jakarta.mail.MessagingException;
import java.net.ConnectException;
import java.net.NoRouteToHostException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import javax.net.ssl.SSLException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailException;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class PasswordResetMailService {
    private static final Logger log = LoggerFactory.getLogger(PasswordResetMailService.class);
    private final ObjectProvider<JavaMailSender> sender;
    private final String host;
    private final String from;
    private final boolean credentialsMissing;

    public PasswordResetMailService(ObjectProvider<JavaMailSender> sender,
                                    @Value("${spring.mail.host:}") String host,
                                    @Value("${app.mail.from:}") String from,
                                    @Value("${spring.mail.properties.mail.smtp.auth:true}") boolean authentication,
                                    @Value("${spring.mail.username:}") String username,
                                    @Value("${spring.mail.password:}") String password) {
        this.sender = sender;
        this.host = host;
        this.from = from;
        this.credentialsMissing = authentication && (username.isBlank() || password.isBlank());
    }

    public void ensureAvailable() {
        var missing = new ArrayList<String>();
        if (host.isBlank()) missing.add("MAIL_HOST");
        if (from.isBlank()) missing.add("MAIL_FROM");
        if (credentialsMissing) missing.add("MAIL_USERNAME / MAIL_PASSWORD");
        if (sender.getIfAvailable() == null) missing.add("JavaMailSender");
        if (!missing.isEmpty()) {
            log.warn("MAIL_NOT_CONFIGURED: missing {}. Set these in the backend process and restart it.",
                    String.join(", ", missing));
            throw unavailable("MAIL_NOT_CONFIGURED");
        }
    }

    public void sendCode(String email, String code) {
        ensureAvailable();
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(email);
        message.setSubject("MediCare — Réinitialisation du mot de passe");
        message.setText("Votre code de vérification MediCare est : " + code
                + "\n\nCe code expire dans 10 minutes et ne peut être utilisé qu'une seule fois."
                + "\nSi vous n'êtes pas à l'origine de cette demande, ignorez cet email.");
        try {
            sender.getObject().send(message);
        } catch (MailException exception) {
            throw deliveryFailure(exception);
        }
    }

    public void sendVerificationCode(String email, String code, String purpose) {
        ensureAvailable();
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from); message.setTo(email);
        message.setSubject("MediCare — Code de vérification");
        message.setText("Votre code de vérification MediCare est : " + code
                + "\n\nCe code expire dans 10 minutes. Ne le communiquez à personne."
                + "\nAction : " + switch (purpose) {
                    case "SIGNUP" -> "Création du compte";
                    case "MFA_LOGIN" -> "Connexion après mot de passe";
                    case "PASSWORDLESS" -> "Connexion sans mot de passe";
                    case "MERGE_PRIMARY", "MERGE_SECONDARY" -> "Rapprochement de deux comptes — ne validez que si vous en êtes à l'origine";
                    case "MFA_ENABLE" -> "Activation de la double vérification";
                    case "MFA_DISABLE" -> "Désactivation de la double vérification";
                    case "RECOVERY_ROTATE" -> "Renouvellement des codes de récupération";
                    default -> "Vérification de votre adresse email";
                });
        try { sender.getObject().send(message); } catch (MailException exception) { throw deliveryFailure(exception); }
    }

    private ApiException deliveryFailure(MailException exception) {
        // Inspect types only: SMTP exception messages can contain addresses, credentials or message contents.
        var pending = new ArrayDeque<Throwable>();
        var visited = Collections.newSetFromMap(new IdentityHashMap<Throwable, Boolean>());
        pending.add(exception);
        boolean authentication = false, tls = false, connection = false;
        while (!pending.isEmpty()) {
            var failure = pending.removeFirst();
            if (!visited.add(failure)) continue;
            authentication |= failure instanceof MailAuthenticationException || failure instanceof AuthenticationFailedException;
            tls |= failure instanceof SSLException;
            connection |= failure instanceof ConnectException || failure instanceof NoRouteToHostException
                    || failure instanceof SocketTimeoutException || failure instanceof UnknownHostException;
            if (failure.getCause() != null) pending.add(failure.getCause());
            if (failure instanceof MessagingException mail && mail.getNextException() != null) pending.add(mail.getNextException());
            if (failure instanceof MailSendException send) Collections.addAll(pending, send.getMessageExceptions());
        }
        String code = authentication ? "MAIL_AUTHENTICATION_FAILED" : tls ? "MAIL_TLS_FAILED"
                : connection ? "MAIL_CONNECTION_FAILED" : "MAIL_SEND_FAILED";
        String advice = switch (code) {
            case "MAIL_AUTHENTICATION_FAILED" -> "Check that MAIL_USERNAME owns the app password in MAIL_PASSWORD; restart the backend after changing it.";
            case "MAIL_TLS_FAILED" -> "Check the SMTP TLS settings, system clock and Java certificates; keep certificate validation enabled.";
            case "MAIL_CONNECTION_FAILED" -> "Check SMTP host/port and outbound network access (Gmail: smtp.gmail.com:587).";
            default -> "Check the sender address, SMTP provider permissions and sending limits.";
        };
        log.warn("{}: {}", code, advice);
        return unavailable(code);
    }

    private ApiException unavailable(String code) {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, code);
    }
}
