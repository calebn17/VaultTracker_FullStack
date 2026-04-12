import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FireProjectionChart } from "../fire-projection-chart";
import { fireProjectionReachable } from "./fixtures";

describe("FireProjectionChart", () => {
  it("renders chart container for non-empty curve", () => {
    const { container } = render(<FireProjectionChart projection={fireProjectionReachable} />);
    expect(container.querySelector("[data-slot='fire-projection-chart']")).toBeInTheDocument();
    expect(screen.getByText(/Regular FIRE/i)).toBeInTheDocument();
  });
});
