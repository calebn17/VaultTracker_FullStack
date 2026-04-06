import type { ReactNode } from "react";
import { SiteHeader } from "@/components/layout/site-header";
import { MobileNav } from "@/components/layout/mobile-nav";
import { cn } from "@/lib/utils";

export function AppShell({
  children,
  contentClassName,
}: {
  children: ReactNode;
  contentClassName?: string;
}) {
  return (
    <div className="relative z-[1] flex min-h-0 flex-1 flex-col">
      <SiteHeader />
      <main className="min-h-0 flex-1 overflow-auto pb-20 md:pb-6">
        <div className={cn("mx-auto max-w-[1400px] px-5 py-8 md:px-10", contentClassName)}>
          {children}
        </div>
      </main>
      <MobileNav />
    </div>
  );
}
