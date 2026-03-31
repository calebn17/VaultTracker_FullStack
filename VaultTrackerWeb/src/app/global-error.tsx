"use client";

import "./globals.css";
import { RouteErrorFallback } from "@/components/route-error-fallback";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-background font-sans text-foreground antialiased">
        <RouteErrorFallback error={error} reset={reset} scope="global" />
      </body>
    </html>
  );
}
