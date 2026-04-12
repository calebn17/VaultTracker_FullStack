import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FireSummaryCards } from "../fire-summary-cards";
import {
  fireProjectionBeyondHorizon,
  fireProjectionReachable,
  fireProjectionUnreachable,
} from "./fixtures";

describe("FireSummaryCards", () => {
  it("renders nothing for unreachable", () => {
    const { container } = render(<FireSummaryCards projection={fireProjectionUnreachable} />);
    expect(container.querySelector("[data-slot='fire-summary-cards']")).toBeNull();
  });

  it("shows monthly surplus and time labels for reachable", () => {
    render(<FireSummaryCards projection={fireProjectionReachable} />);
    expect(screen.getByText(/Monthly surplus/i)).toBeInTheDocument();
    expect(screen.getByText(/Time to Regular FIRE/i)).toBeInTheDocument();
    expect(screen.getByText(/12 yr/i)).toBeInTheDocument();
  });

  it("shows em dash for months when beyond horizon", () => {
    render(<FireSummaryCards projection={fireProjectionBeyondHorizon} />);
    const list = screen.getByRole("list");
    expect(list).toBeInTheDocument();
    expect(list.textContent).toContain("—");
  });
});
