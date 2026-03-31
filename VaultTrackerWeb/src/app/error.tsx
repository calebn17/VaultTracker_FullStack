"use client";

import { RouteErrorFallback } from "@/components/route-error-fallback";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return <RouteErrorFallback error={error} reset={reset} scope="root" />;
}
