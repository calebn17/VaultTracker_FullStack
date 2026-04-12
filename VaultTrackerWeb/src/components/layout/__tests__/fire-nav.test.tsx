import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { SiteHeader } from "@/components/layout/site-header";
import { MobileNav } from "@/components/layout/mobile-nav";

vi.mock("next/navigation", () => ({
  usePathname: () => "/dashboard",
}));

vi.mock("next-themes", () => ({
  useTheme: () => ({ theme: "dark", setTheme: vi.fn() }),
}));

vi.mock("@/contexts/auth-context", () => ({
  useAuth: () => ({ user: null, loading: false, mode: "debug" as const }),
}));

describe("FIRE nav links", () => {
  it("SiteHeader includes FIRE Calc pointing at /fire", () => {
    render(<SiteHeader />);
    const link = screen.getByRole("link", { name: "FIRE Calc" });
    expect(link).toHaveAttribute("href", "/fire");
  });

  it("MobileNav includes FIRE pointing at /fire", () => {
    render(<MobileNav />);
    const link = screen.getByRole("link", { name: "FIRE" });
    expect(link).toHaveAttribute("href", "/fire");
  });
});
