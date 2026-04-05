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
});
