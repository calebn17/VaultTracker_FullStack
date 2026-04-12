import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import FirePage from "../page";

describe("FirePage", () => {
  it("renders a named region and primary heading", () => {
    render(<FirePage />);
    expect(screen.getByRole("region", { name: /FIRE calculator/i })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: /FIRE calculator/i })).toBeInTheDocument();
  });
});
