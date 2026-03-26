import type { ReactNode } from "react";
import { Sidebar } from "@/components/layout/sidebar";
import { MobileNav } from "@/components/layout/mobile-nav";

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-0 flex-1">
      <div className="hidden h-full md:block">
        <Sidebar />
      </div>
      <main className="min-h-0 flex-1 overflow-auto pb-20 md:pb-4">
        <div className="mx-auto max-w-6xl p-4 md:p-6">{children}</div>
      </main>
      <MobileNav />
    </div>
  );
}
