import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FireTargetsTable } from "../fire-targets-table";
import { fireProjectionReachable } from "./fixtures";

describe("FireTargetsTable", () => {
  it("renders three FIRE tiers with amounts from projection", () => {
    render(<FireTargetsTable targets={fireProjectionReachable.fireTargets} />);
    expect(screen.getByText("Lean FIRE")).toBeInTheDocument();
    expect(screen.getByText("Regular FIRE")).toBeInTheDocument();
    expect(screen.getByText("Fat FIRE")).toBeInTheDocument();
    expect(screen.getByText("$1,375,000.00")).toBeInTheDocument();
  });
});
