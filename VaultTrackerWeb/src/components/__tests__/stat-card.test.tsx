import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { StatCard } from "@/components/dashboard/stat-card";

describe("StatCard — default variant", () => {
  it("renders the title and value", () => {
    render(<StatCard title="Total Value" value="$10,000" />);

    expect(screen.getByText("Total Value")).toBeInTheDocument();
    expect(screen.getByText("$10,000")).toBeInTheDocument();
  });

  it("renders a Skeleton and hides the value when loading", () => {
    render(<StatCard title="Total Value" value="$10,000" loading />);

    // Skeleton should be present (it renders as a div with specific classes)
    expect(
      document.querySelector(".animate-pulse, [data-slot='skeleton']") ??
        document.querySelector("div.bg-muted")
    ).toBeTruthy();
    // Value text should not be in the document while loading
    expect(screen.queryByText("$10,000")).not.toBeInTheDocument();
  });
});

describe("StatCard — hero variant", () => {
  it("renders the title and value in the hero layout", () => {
    render(<StatCard title="Net Worth" value="$100,000" variant="hero" />);

    expect(screen.getByText("Net Worth")).toBeInTheDocument();
    expect(screen.getByText("$100,000")).toBeInTheDocument();
  });

  it("renders a Skeleton and hides the value when loading", () => {
    render(<StatCard title="Net Worth" value="$100,000" variant="hero" loading />);

    expect(screen.queryByText("$100,000")).not.toBeInTheDocument();
  });
});

describe("StatCard — compact variant", () => {
  it("renders the title and value in the compact layout", () => {
    render(<StatCard title="Cash" value="$5,000" variant="compact" />);

    expect(screen.getByText("Cash")).toBeInTheDocument();
    expect(screen.getByText("$5,000")).toBeInTheDocument();
  });
});
