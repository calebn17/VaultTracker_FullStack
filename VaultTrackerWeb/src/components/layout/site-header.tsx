"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { format } from "date-fns";
import {
  LayoutDashboard,
  PieChart,
  ListOrdered,
  Wallet,
  Sun,
  Moon,
} from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { cn } from "@/lib/utils";
import { useAuth } from "@/contexts/auth-context";

const links = [
  { href: "/dashboard", label: "Home", icon: LayoutDashboard },
  { href: "/analytics", label: "Charts", icon: PieChart },
  { href: "/transactions", label: "Transactions", icon: ListOrdered },
  { href: "/accounts", label: "Accounts", icon: Wallet },
] as const;

export function SiteHeader() {
  const pathname = usePathname();
  const { theme, setTheme } = useTheme();
  const { user, mode } = useAuth();

  const initial =
    user?.displayName?.[0] ??
    user?.email?.[0] ??
    (mode === "debug" ? "D" : "?");

  const dateChip = format(new Date(), "EEE, MMM d, yyyy");

  return (
    <header className="border-border/80 bg-background/80 supports-[backdrop-filter]:bg-background/70 sticky top-0 z-50 border-b backdrop-blur-xl">
      <div className="mx-auto flex max-w-[1400px] items-center justify-between gap-3 px-5 py-5 md:px-10">
        <div className="flex min-w-0 items-center gap-6 md:gap-10">
          <Link
            href="/dashboard"
            className="font-serif text-[22px] tracking-tight text-foreground shrink-0"
          >
            vaulttracker<span className="text-primary">.</span>
          </Link>
          <nav className="hidden items-center gap-0.5 md:flex" aria-label="Main">
            {links.map(({ href, label }) => {
              const active =
                pathname === href || pathname.startsWith(`${href}/`);
              return (
                <Link
                  key={href}
                  href={href}
                  className={cn(
                    "rounded-md px-2.5 py-1.5 font-mono text-[11px] tracking-wide transition-colors",
                    active
                      ? "border-border bg-card text-foreground border"
                      : "text-muted-foreground hover:text-foreground"
                  )}
                >
                  {label}
                </Link>
              );
            })}
          </nav>
        </div>
        <div className="flex items-center gap-2 md:gap-3">
          <span
            className="text-muted-foreground hidden text-[11px] tracking-[0.08em] uppercase sm:inline"
            suppressHydrationWarning
          >
            {dateChip}
          </span>
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            className="text-muted-foreground"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            aria-label="Toggle theme"
          >
            {theme === "dark" ? (
              <Sun className="size-4" />
            ) : (
              <Moon className="size-4" />
            )}
          </Button>
          <Link
            href="/profile"
            className="ring-offset-background shrink-0 rounded-full ring-2 ring-transparent transition-[box-shadow] hover:ring-primary/40 focus-visible:ring-ring focus-visible:outline-none"
          >
            <Avatar className="size-8 border border-border">
              {user?.photoURL ? (
                <AvatarImage src={user.photoURL} alt="" />
              ) : null}
              <AvatarFallback className="bg-secondary text-[11px] font-medium">
                {initial}
              </AvatarFallback>
            </Avatar>
          </Link>
        </div>
      </div>
    </header>
  );
}
