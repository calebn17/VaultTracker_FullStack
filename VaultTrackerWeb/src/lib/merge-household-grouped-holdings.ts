import type { Category, DashboardResponse, HouseholdMemberDashboard } from "@/types/api";

const GROUP_KEYS: Category[] = ["crypto", "stocks", "cash", "realEstate", "retirement"];

/** Concatenate each member's grouped holdings for household-level grids and bento cards. */
export function mergeHouseholdMemberHoldings(
  members: HouseholdMemberDashboard[]
): DashboardResponse["groupedHoldings"] {
  const grouped: DashboardResponse["groupedHoldings"] = {
    crypto: [],
    stocks: [],
    cash: [],
    realEstate: [],
    retirement: [],
  };
  for (const m of members) {
    for (const cat of GROUP_KEYS) {
      const list = m.groupedHoldings[cat];
      if (list?.length) grouped[cat] = [...grouped[cat], ...list];
    }
  }
  return grouped;
}
