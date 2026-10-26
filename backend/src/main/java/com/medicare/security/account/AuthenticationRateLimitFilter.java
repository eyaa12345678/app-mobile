package com.medicare.security.account;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.annotation.Order;
import org.springframework.core.Ordered;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
@Component @Order(Ordered.HIGHEST_PRECEDENCE + 20)
public class AuthenticationRateLimitFilter extends OncePerRequestFilter {
    private static final long WINDOW = 300_000;
    private record Counter(long start, int count) {}
    private final ConcurrentHashMap<String, Counter> counters = new ConcurrentHashMap<>();
    @Value("${app.security.rate-limit-enabled:true}") private boolean enabled;
    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain) throws ServletException, IOException {
        String path = request.getServletPath();
        boolean limited = "POST".equals(request.getMethod()) && (path.startsWith("/api/auth/") || path.equals("/api/security/challenge") || path.equals("/api/security/merges"));
        if (!enabled || !limited) { chain.doFilter(request, response); return; }
        long now = System.currentTimeMillis();
        if (counters.size() >= 10000) counters.entrySet().removeIf(e -> now - e.getValue().start() >= WINDOW);
        String key = request.getRemoteAddr(); // Do not trust client-supplied X-Forwarded-For.
        if (counters.size() >= 10000 && !counters.containsKey(key)) { reject(response); return; }
        Counter count = counters.compute(key, (k, old) -> old == null || now - old.start() >= WINDOW ? new Counter(now, 1) : new Counter(old.start(), old.count() + 1));
        if (count.count() > 60) { reject(response); return; }
        chain.doFilter(request, response);
    }
    private void reject(HttpServletResponse response) throws IOException {
        response.setStatus(429); response.setHeader("Retry-After", "300"); response.setContentType("application/json");
        response.getWriter().write("{\"message\":\"AUTH_RATE_LIMITED\"}");
    }
}
