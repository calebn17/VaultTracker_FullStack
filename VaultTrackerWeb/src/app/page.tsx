"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/auth-context";
import { Skeleton } from "@/components/ui/skeleton";

export default function HomePage() {
  const router = useRouter();
  const { user, loading, mode } = useAuth();

  useEffect(() => {
    if (loading) return;
    if (user || mode === "debug") {
      router.replace("/dashboard");
    } else {
      router.replace("/login");
    }
  }, [user, loading, mode, router]);

  return (
    <div className="flex flex-1 items-center justify-center p-8">
      <Skeleton className="h-8 w-48" />
    </div>
  );
}
