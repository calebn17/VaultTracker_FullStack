"use client";

import { RouteErrorFallback } from "@/components/route-error-fallback";

export default function AuthenticatedError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <RouteErrorFallback error={error} reset={reset} scope="authenticated" />
  );
}
