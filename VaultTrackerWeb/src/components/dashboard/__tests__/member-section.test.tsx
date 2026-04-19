import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import React from "react";
import type { HouseholdMemberDashboard } from "@/types/api";
import { HouseholdMemberSections } from "../member-section";

const zeros = { crypto: 0, stocks: 0, cash: 0, realEstate: 0, retirement: 0 };
const emptyGrouped = {
  crypto: [],
  stocks: [],
  cash: [],
  realEstate: [],
  retirement: [],
} as HouseholdMemberDashboard["groupedHoldings"];

const members: HouseholdMemberDashboard[] = [
  {
    userId: "u1",
    email: "alpha@test.com",
    totalNetWorth: 100,
    categoryTotals: zeros,
    groupedHoldings: emptyGrouped,
  },
  {
    userId: "u2",
    email: "beta@test.com",
    totalNetWorth: 200,
    categoryTotals: zeros,
    groupedHoldings: emptyGrouped,
  },
];

describe("HouseholdMemberSections", () => {
  it("renders a labeled region and member labels", () => {
    render(<HouseholdMemberSections members={members} loading={false} />);
    expect(screen.getByRole("region", { name: /household members/i })).toBeInTheDocument();
    expect(screen.getByText("alpha@test.com")).toBeInTheDocument();
    expect(screen.getByText("beta@test.com")).toBeInTheDocument();
  });

  it("collapses a member section when header is clicked", async () => {
    const user = userEvent.setup();
    render(<HouseholdMemberSections members={members} loading={false} />);
    const expandAlpha = screen.getByRole("button", {
      name: /collapse holdings for alpha@test.com/i,
    });
    await user.click(expandAlpha);
    expect(
      screen.getByRole("button", { name: /expand holdings for alpha@test.com/i })
    ).toBeInTheDocument();
  });
});
