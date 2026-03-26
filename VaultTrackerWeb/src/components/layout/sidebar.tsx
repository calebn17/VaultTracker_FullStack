"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  PieChart,
  ListOrdered,
  Wallet,
  User,
  Moon,
  Sun,
} from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";
import { useAuth } from "@/contexts/auth-context";

const links = [
  { href: "/dashboard", label: "Home", icon: LayoutDashboard },
  { href: "/analytics", label: "Charts", icon: PieChart },
  { href: "/transactions", label: "Transactions", icon: ListOrdered },
  { href: "/accounts", label: "Accounts", icon: Wallet },
  { href: "/profile", label: "Profile", icon: User },
];

export function Sidebar() {
  const pathname = usePathname();
  const { theme, setTheme } = useTheme();
  const { user, mode } = useAuth();

  const initial =
    user?.displayName?.[0] ??
    user?.email?.[0] ??
    (mode === "debug" ? "D" : "?");

  return (
    <aside className="bg-sidebar text-sidebar-foreground flex h-full w-56 shrink-0 flex-col border-r border-sidebar-border">
      <div className="flex items-center gap-2 px-4 py-4">
        <span className="text-lg font-semibold tracking-tight">VaultTracker</span>
      </div>
      <Separator />
      <nav className="flex flex-1 flex-col gap-1 p-2">
        {links.map(({ href, label, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            className={cn(
              "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              pathname === href || pathname.startsWith(`${href}/`)
                ? "bg-sidebar-accent text-sidebar-accent-foreground"
                : "hover:bg-sidebar-accent/60"
            )}
          >
            <Icon className="size-4 shrink-0" />
            {label}
          </Link>
        ))}
      </nav>
      <Separator />
      <div className="flex flex-col gap-2 p-3">
        <Button
          variant="ghost"
          size="sm"
          className="justify-start"
          onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
        >
          {theme === "dark" ? (
            <Sun className="mr-2 size-4" />
          ) : (
            <Moon className="mr-2 size-4" />
          )}
          Theme
        </Button>
        <div className="flex items-center gap-2 px-1">
          <Avatar className="size-8">
            {user?.photoURL ? (
              <AvatarImage src={user.photoURL} alt="" />
            ) : null}
            <AvatarFallback>{initial}</AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1 text-xs">
            <p className="truncate font-medium">
              {user?.displayName ?? (mode === "debug" ? "Debug user" : "Signed in")}
            </p>
            {user?.email ? (
              <p className="text-muted-foreground truncate">{user.email}</p>
            ) : null}
          </div>
        </div>
      </div>
    </aside>
  );
}
