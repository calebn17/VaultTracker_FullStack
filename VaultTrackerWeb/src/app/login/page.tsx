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
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Sign in</CardTitle>
          <CardDescription>
            Use the same Google account as the iOS app to see your portfolio.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {isFirebaseConfigured ? (
            <Button
              type="button"
              onClick={() => signInWithGoogle().catch(console.error)}
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
          {process.env.NODE_ENV === "development" ? (
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
