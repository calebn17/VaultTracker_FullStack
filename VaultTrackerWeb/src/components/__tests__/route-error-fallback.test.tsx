import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

const mockLoggerError = vi.hoisted(() => vi.fn());

vi.mock("@/lib/logger", () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: mockLoggerError,
  },
}));

vi.mock("next/link", () => ({
  default: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>{children}</a>
  ),
}));

import { ApiError } from "@/lib/api-client";
import { RouteErrorFallback } from "../route-error-fallback";

describe("RouteErrorFallback", () => {
  it("logs error on mount with digest in context", async () => {
    const err = new Error("boom") as Error & { digest?: string };
    err.digest = "digest-abc";
    const reset = vi.fn();

    render(<RouteErrorFallback error={err} reset={reset} scope="root" />);

    await waitFor(() => {
      expect(mockLoggerError).toHaveBeenCalledWith(
        "Route error (root)",
        err,
        { digest: "digest-abc" },
        {
          tags: { route_error_scope: "root" },
          contexts: { route_error: { digest: "digest-abc" } },
        }
      );
    });
  });

  it("logs error without digest context when digest is absent", async () => {
    const err = new Error("no-digest");
    const reset = vi.fn();

    render(<RouteErrorFallback error={err} reset={reset} scope="root" />);

    await waitFor(() => {
      expect(mockLoggerError).toHaveBeenCalledWith("Route error (root)", err, undefined, {
        tags: { route_error_scope: "root" },
      });
    });
  });

  it("calls reset when Try again is clicked", async () => {
    const user = userEvent.setup();
    const err = new Error("x");
    const reset = vi.fn();

    render(<RouteErrorFallback error={err} reset={reset} scope="authenticated" />);

    await user.click(screen.getByRole("button", { name: /try again/i }));
    expect(reset).toHaveBeenCalledTimes(1);
  });

  it("shows Return to login for ApiError 401", () => {
    const err = new ApiError("unauthorized", 401);
    const reset = vi.fn();

    render(<RouteErrorFallback error={err} reset={reset} scope="authenticated" />);

    expect(screen.getByRole("heading", { name: /session problem/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /return to login/i })).toHaveAttribute(
      "href",
      "/login"
    );
    expect(screen.getByRole("button", { name: /try again/i })).toBeInTheDocument();
  });

  it("shows Return to login when message is Not signed in", () => {
    const err = new Error("Not signed in");
    const reset = vi.fn();

    render(<RouteErrorFallback error={err} reset={reset} scope="root" />);

    expect(screen.getByRole("link", { name: /return to login/i })).toBeInTheDocument();
  });
});
