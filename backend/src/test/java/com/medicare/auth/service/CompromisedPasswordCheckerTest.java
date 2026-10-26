package com.medicare.auth.service;
import com.medicare.common.ApiException;
import java.net.http.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
class CompromisedPasswordCheckerTest {
    @SuppressWarnings("unchecked")
    @Test void sendsOnlyFiveHashCharactersWithPaddingAndFindsCompromisedSuffix() throws Exception {
        HttpClient client = mock(HttpClient.class); HttpResponse<String> response = mock(HttpResponse.class);
        when(response.statusCode()).thenReturn(200);
        when(response.body()).thenReturn("1E4C9B93F3F0682250B6CF8331B7EE68FD8:123\r\nFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:0\r\n");
        when(client.send(any(HttpRequest.class), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any())).thenReturn(response);
        assertThat(new CompromisedPasswordChecker(true, client).isCompromised("password")).isTrue();
        var request = ArgumentCaptor.forClass(HttpRequest.class);
        verify(client).send(request.capture(), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any());
        assertThat(request.getValue().uri().toString()).isEqualTo("https://api.pwnedpasswords.com/range/5BAA6");
        assertThat(request.getValue().headers().firstValue("Add-Padding")).contains("true");
        assertThat(request.getValue().bodyPublisher()).isEmpty();
    }
    @SuppressWarnings("unchecked")
    @Test void paddingRowsWithZeroCountAreNotTreatedAsCompromised() throws Exception {
        HttpClient client = mock(HttpClient.class); HttpResponse<String> response = mock(HttpResponse.class);
        when(response.statusCode()).thenReturn(200); when(response.body()).thenReturn("1E4C9B93F3F0682250B6CF8331B7EE68FD8:0\n");
        when(client.send(any(HttpRequest.class), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any())).thenReturn(response);
        assertThat(new CompromisedPasswordChecker(true, client).isCompromised("password")).isFalse();
    }
    @SuppressWarnings("unchecked")
    @Test void serviceErrorsAndMalformedResponsesFailClosed() throws Exception {
        HttpClient client = mock(HttpClient.class); HttpResponse<String> response = mock(HttpResponse.class);
        when(client.send(any(HttpRequest.class), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any())).thenReturn(response);
        when(response.statusCode()).thenReturn(503);
        assertThatThrownBy(() -> new CompromisedPasswordChecker(true, client).isCompromised("password")).isInstanceOf(ApiException.class);
        when(response.statusCode()).thenReturn(200); when(response.body()).thenReturn("not a valid range response");
        assertThatThrownBy(() -> new CompromisedPasswordChecker(true, client).isCompromised("password")).isInstanceOf(ApiException.class);
    }
}
