"use client";

import { useLayoutEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell } from "@/components/layout/app-shell";
import { useAuth } from "@/contexts/auth-context";
import { Skeleton } from "@/components/ui/skeleton";

function LoginGateRedirect() {
  const router = useRouter();

  useLayoutEffect(() => {
    router.replace("/login");
  }, [router]);

  return (
    <div className="flex flex-1 flex-col gap-4 p-6">
      <Skeleton className="h-10 w-64" />
      <Skeleton className="h-64 w-full max-w-3xl" />
    </div>
  );
}

export default function AuthenticatedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex flex-1 flex-col gap-4 p-6">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-64 w-full max-w-3xl" />
      </div>
    );
  }

  if (!user) {
    return <LoginGateRedirect />;
  }

  return <AppShell>{children}</AppShell>;
}
