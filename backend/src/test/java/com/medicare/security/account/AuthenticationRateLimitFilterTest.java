package com.medicare.security.account;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import org.springframework.test.util.ReflectionTestUtils;
import static org.assertj.core.api.Assertions.assertThat;
class AuthenticationRateLimitFilterTest {
    @Test void repeatedRequestsAreLimitedAndForwardedHeadersDoNotBypassTheLimit() throws Exception {
        var filter = new AuthenticationRateLimitFilter(); ReflectionTestUtils.setField(filter, "enabled", true);
        var passed = new AtomicInteger();
        for (int i = 0; i < 61; i++) {
            var request = new MockHttpServletRequest("POST", "/api/auth/login"); request.setServletPath("/api/auth/login");
            request.setRemoteAddr("127.0.0.20"); request.addHeader("X-Forwarded-For", "10.0.0."+i);
            var response = new MockHttpServletResponse();
            filter.doFilter(request, response, (req, res) -> passed.incrementAndGet());
            if (i == 60) { assertThat(response.getStatus()).isEqualTo(429); assertThat(response.getHeader("Retry-After")).isEqualTo("300"); }
        }
        assertThat(passed.get()).isEqualTo(60);
    }
}
