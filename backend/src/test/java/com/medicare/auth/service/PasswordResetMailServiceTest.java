package com.medicare.auth.service;

import com.medicare.common.ApiException;
import jakarta.mail.AuthenticationFailedException;
import jakarta.mail.MessagingException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.util.Map;
import javax.net.ssl.SSLHandshakeException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(OutputCaptureExtension.class)
class PasswordResetMailServiceTest {
    private static final String SENSITIVE = "secret-app-password 123456 recipient@example.test";
    private JavaMailSender sender;
    private ObjectProvider<JavaMailSender> provider;
    private PasswordResetMailService mail;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void prepare() {
        sender = mock(JavaMailSender.class);
        provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenReturn(sender);
        when(provider.getObject()).thenReturn(sender);
        mail = configured(true, "username@example.test", "app-password");
    }

    private PasswordResetMailService configured(boolean auth, String username, String password) {
        return new PasswordResetMailService(provider, "smtp.example.test", "sender@example.test", auth, username, password);
    }

    private void expectFailure(String code, CapturedOutput output) {
        assertThatThrownBy(() -> mail.sendVerificationCode("recipient@example.test", "123456", "SIGNUP"))
                .isInstanceOfSatisfying(ApiException.class, failure -> {
                    assertThat(failure.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(failure.getMessage()).isEqualTo(code);
                });
        assertThat(output.getAll()).contains(code).doesNotContain(SENSITIVE, "recipient@example.test", "123456");
    }

    @Test void missingConfigurationNamesOnlyTheMissingSettings(CapturedOutput output) {
        mail = new PasswordResetMailService(provider, "", "", true, "", "");
        expectFailure("MAIL_NOT_CONFIGURED", output);
        assertThat(output.getAll()).contains("MAIL_HOST", "MAIL_FROM", "MAIL_USERNAME", "MAIL_PASSWORD");
        verifyNoInteractions(sender);
    }

    @Test void requiredAuthenticationCannotStartWithoutCredentials(CapturedOutput output) {
        mail = configured(true, "username@example.test", "");
        expectFailure("MAIL_NOT_CONFIGURED", output);
        verifyNoInteractions(sender);
    }

    @Test void localSmtpCanDisableAuthentication() {
        mail = configured(false, "", "");
        mail.sendVerificationCode("recipient@example.test", "123456", "SIGNUP");
        verify(sender).send(any(SimpleMailMessage.class));
    }

    @Test void gmailAuthenticationFailureHasASafeDiagnostic(CapturedOutput output) {
        doThrow(new MailAuthenticationException(SENSITIVE)).when(sender).send(any(SimpleMailMessage.class));
        expectFailure("MAIL_AUTHENTICATION_FAILED", output);
    }

    @Test void nestedTransportAuthenticationFailureIsRecognized(CapturedOutput output) {
        var transport = new MessagingException(SENSITIVE);
        transport.setNextException(new AuthenticationFailedException(SENSITIVE));
        doThrow(new MailSendException(SENSITIVE, transport)).when(sender).send(any(SimpleMailMessage.class));
        expectFailure("MAIL_AUTHENTICATION_FAILED", output);
    }

    @Test void networkFailuresAreSeparatedFromAuthentication(CapturedOutput output) {
        for (var failure : new Exception[]{new ConnectException(SENSITIVE),
                new UnknownHostException(SENSITIVE), new SocketTimeoutException(SENSITIVE)}) {
            doThrow(new MailSendException(SENSITIVE, failure)).when(sender).send(any(SimpleMailMessage.class));
            expectFailure("MAIL_CONNECTION_FAILED", output);
        }
    }

    @Test void failedMessageTransportCausesAreAlsoInspected(CapturedOutput output) {
        doThrow(new MailSendException(Map.of(new Object(), new ConnectException(SENSITIVE))))
                .when(sender).send(any(SimpleMailMessage.class));
        expectFailure("MAIL_CONNECTION_FAILED", output);
    }

    @Test void tlsFailureDoesNotRecommendDisablingCertificateValidation(CapturedOutput output) {
        doThrow(new MailSendException(SENSITIVE, new SSLHandshakeException(SENSITIVE)))
                .when(sender).send(any(SimpleMailMessage.class));
        expectFailure("MAIL_TLS_FAILED", output);
        assertThat(output.getAll()).contains("keep certificate validation enabled");
    }

    @Test void deliveryFailureNeverReturnsRawProviderDetails(CapturedOutput output) {
        doThrow(new MailSendException(SENSITIVE)).when(sender).send(any(SimpleMailMessage.class));
        expectFailure("MAIL_SEND_FAILED", output);
    }

    @Test void passwordResetUsesTheSameSafeDiagnostics(CapturedOutput output) {
        doThrow(new MailAuthenticationException(SENSITIVE)).when(sender).send(any(SimpleMailMessage.class));
        assertThatThrownBy(() -> mail.sendCode("recipient@example.test", "123456"))
                .isInstanceOfSatisfying(ApiException.class,
                        failure -> assertThat(failure.getMessage()).isEqualTo("MAIL_AUTHENTICATION_FAILED"));
        assertThat(output.getAll()).doesNotContain(SENSITIVE, "123456");
    }
}
