"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useAuth } from "@/contexts/auth-context";
import { isFirebaseConfigured } from "@/lib/firebase";
import { logger } from "@/lib/logger";

export default function LoginPage() {
  const router = useRouter();
  const { user, loading, signInWithGoogle, signInDebug } = useAuth();

  useEffect(() => {
    if (!loading && user) {
      router.replace("/dashboard");
    }
  }, [user, loading, router]);

  return (
    <div className="flex min-h-full flex-1 items-center justify-center p-6">
      <Card className="bg-card w-full max-w-md rounded-2xl border shadow-2xl">
        <CardHeader>
          <CardTitle className="font-serif text-2xl tracking-tight">
            Sign in
          </CardTitle>
          <CardDescription className="font-mono text-xs">
            Use the same Google account as the iOS app to see your portfolio.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {isFirebaseConfigured ? (
            <Button
              type="button"
              onClick={() =>
                void signInWithGoogle().catch((e) =>
                  logger.error("Google sign-in failed", e)
                )
              }
              disabled={loading}
            >
              Continue with Google
            </Button>
          ) : (
            <p className="text-muted-foreground text-sm">
              Add Firebase keys to <code className="text-xs">.env.local</code>{" "}
              (see <code className="text-xs">.env.local.example</code>) to
              enable Google sign-in.
            </p>
          )}
          {process.env.NODE_ENV === "development" && signInDebug ? (
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                signInDebug();
                router.replace("/dashboard");
              }}
            >
              Debug API session (local only)
            </Button>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
