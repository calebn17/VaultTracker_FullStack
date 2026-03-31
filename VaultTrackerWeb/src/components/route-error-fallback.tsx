"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { logger } from "@/lib/logger";

/** Dedupe logging when React Strict Mode runs effects twice with the same error reference. */
const loggedRouteErrors = new WeakSet<object>();

type RouteErrorFallbackProps = {
  error: Error & { digest?: string };
  reset: () => void;
  /** Distinguishes root vs authenticated segment vs global root layout in logs */
  scope: "root" | "authenticated" | "global";
};

function routeErrorContext(error: Error & { digest?: string }) {
  if (typeof error.digest === "string" && error.digest.length > 0) {
    return { digest: error.digest };
  }
  return undefined;
}

export function RouteErrorFallback({
  error,
  reset,
  scope,
}: RouteErrorFallbackProps) {
  useEffect(() => {
    if (loggedRouteErrors.has(error)) {
      return;
    }
    loggedRouteErrors.add(error);

    const ctx = routeErrorContext(error);

    logger.error(`Route error (${scope})`, error, ctx, {
      tags: { route_error_scope: scope },
      contexts: ctx ? { route_error: ctx } : undefined,
    });
  }, [error, scope]);

  return (
    <div className="flex min-h-[40vh] flex-col items-center justify-center gap-4 p-6">
      <h2 className="font-serif text-xl tracking-tight">Something went wrong</h2>
      <p className="text-muted-foreground max-w-md text-center text-sm">
        An unexpected error occurred. You can try again or refresh the page.
      </p>
      <Button type="button" onClick={() => reset()}>
        Try again
      </Button>
    </div>
  );
}
