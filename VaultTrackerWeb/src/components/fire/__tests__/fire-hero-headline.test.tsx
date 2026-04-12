import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FireHeroHeadline } from "../fire-hero-headline";
import {
  fireProjectionBeyondHorizon,
  fireProjectionReachable,
  fireProjectionUnreachable,
} from "./fixtures";

describe("FireHeroHeadline", () => {
  it("shows unreachable copy for non-positive savings", () => {
    render(<FireHeroHeadline projection={fireProjectionUnreachable} />);
    expect(
      screen.getByText(/At your current savings rate, FIRE is not achievable/i)
    ).toBeInTheDocument();
  });

  it("shows beyond-horizon copy distinct from unreachable", () => {
    render(<FireHeroHeadline projection={fireProjectionBeyondHorizon} />);
    expect(screen.getByText(/30-year projection window/i)).toBeInTheDocument();
    expect(
      screen.queryByText(/At your current savings rate, FIRE is not achievable/i)
    ).not.toBeInTheDocument();
  });

  it("shows Regular FIRE timeline when reachable", () => {
    render(<FireHeroHeadline projection={fireProjectionReachable} />);
    expect(screen.getByText(/Regular FIRE/i)).toBeInTheDocument();
    expect(screen.getByText(/12/)).toBeInTheDocument();
    expect(screen.getByText(/47/)).toBeInTheDocument();
  });
});
