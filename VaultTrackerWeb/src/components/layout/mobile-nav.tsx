"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  PieChart,
  ListOrdered,
  Wallet,
  User,
} from "lucide-react";
import { cn } from "@/lib/utils";

const links = [
  { href: "/dashboard", label: "Home", icon: LayoutDashboard },
  { href: "/analytics", label: "Charts", icon: PieChart },
  { href: "/transactions", label: "Txns", icon: ListOrdered },
  { href: "/accounts", label: "Accts", icon: Wallet },
  { href: "/profile", label: "Profile", icon: User },
];

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav className="border-border bg-background/90 supports-[backdrop-filter]:bg-background/85 fixed bottom-0 left-0 right-0 z-50 flex border-t backdrop-blur-md md:hidden">
      {links.map(({ href, label, icon: Icon }) => (
        <Link
          key={href}
          href={href}
          className={cn(
            "text-muted-foreground flex flex-1 flex-col items-center gap-0.5 py-2 font-mono text-[10px] font-medium tracking-wide",
            pathname === href && "text-primary"
          )}
        >
          <Icon className="size-5" />
          {label}
        </Link>
      ))}
    </nav>
  );
}
