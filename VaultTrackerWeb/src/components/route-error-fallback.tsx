"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { logger } from "@/lib/logger";

type RouteErrorFallbackProps = {
  error: Error & { digest?: string };
  reset: () => void;
  /** Distinguishes root vs authenticated segment in logs */
  scope: "root" | "authenticated";
};

export function RouteErrorFallback({
  error,
  reset,
  scope,
}: RouteErrorFallbackProps) {
  useEffect(() => {
    logger.error(`Route error (${scope})`, error, { digest: error.digest });
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
