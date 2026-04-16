import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";

const isDev = process.env.NODE_ENV === "development";

/**
 * Content-Security-Policy: tuned for Next.js (incl. dev HMR), Firebase Auth, API calls,
 * and Sentry. Verify in the browser console after login and main flows.
 *
 * Production script-src includes 'unsafe-inline' on purpose: the App Router still emits
 * inline scripts for hydration / RSC payloads, and a nonce-based CSP would require
 * middleware-generated nonces plus aligned next/script usage across the tree. Treat
 * inline scripts as a known XSS hardening gap until that work ships; other directives
 * (default-src, connect-src, frame-ancestors) still narrow the attack surface.
 */
function contentSecurityPolicy(): string {
  const connectSrc = [
    "'self'",
    "https://vaulttracker-api.onrender.com",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://identitytoolkit.googleapis.com",
    "https://securetoken.googleapis.com",
    "https://www.googleapis.com",
    "https://firebase.googleapis.com",
    "https://accounts.google.com",
    "https://*.firebaseio.com",
    "wss://*.firebaseio.com",
    "https://*.ingest.sentry.io",
    "https://*.ingest.de.sentry.io",
  ];
  if (isDev) {
    connectSrc.push("ws://localhost:3000", "ws://127.0.0.1:3000");
  }

  // Dev: eval + inline for HMR. Prod: inline only — see file-level CSP note (nonce TBD).
  const scriptSrc = isDev ? "'self' 'unsafe-eval' 'unsafe-inline'" : "'self' 'unsafe-inline'";

  return [
    "default-src 'self'",
    `script-src ${scriptSrc}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "font-src 'self' data:",
    `connect-src ${connectSrc.join(" ")}`,
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; ");
}

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "Content-Security-Policy",
            value: contentSecurityPolicy(),
          },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          {
            key: "Strict-Transport-Security",
            value: "max-age=31536000; includeSubDomains",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
    ];
  },
};

export default withSentryConfig(nextConfig, {
  silent: true,
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  authToken: process.env.SENTRY_AUTH_TOKEN,
});
