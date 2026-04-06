import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi, beforeEach } from "vitest";
import type { EnrichedTransaction } from "@/types/api";

vi.mock("@/lib/queries/use-transactions", () => ({
  useTransactions: vi.fn(),
}));

import { useTransactions } from "@/lib/queries/use-transactions";
import { AssetDetailDialog } from "@/components/dashboard/asset-detail-dialog";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";

const mockHolding = {
  id: "asset-1",
  name: "Bitcoin",
  symbol: "BTC",
  quantity: 0.5,
  current_value: 30000,
};

const mockCashHolding = {
  id: "asset-cash",
  name: "Chase Checking",
  symbol: null,
  quantity: 18000,
  current_value: 18000,
};

const mockRealEstateHolding = {
  id: "asset-re",
  name: "Oak Street Condo",
  symbol: null,
  quantity: 1,
  current_value: 450000,
};

const mockTransactions: EnrichedTransaction[] = [
  {
    id: "tx-1",
    user_id: "u1",
    asset_id: "asset-1",
    account_id: "acc-1",
    transaction_type: "buy",
    quantity: 0.6,
    price_per_unit: 40000,
    total_value: 24000,
    date: "2024-01-01T00:00:00Z",
    asset: { id: "asset-1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-2",
    user_id: "u1",
    asset_id: "asset-1",
    account_id: "acc-1",
    transaction_type: "sell",
    quantity: 0.1,
    price_per_unit: 45000,
    total_value: 4500,
    date: "2024-06-01T00:00:00Z",
    asset: { id: "asset-1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-3",
    user_id: "u1",
    asset_id: "asset-99",
    account_id: "acc-1",
    transaction_type: "buy",
    quantity: 10,
    price_per_unit: 100,
    total_value: 1000,
    date: "2024-03-01T00:00:00Z",
    asset: {
      id: "asset-99",
      name: "Ethereum",
      symbol: "ETH",
      category: "crypto",
    },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-4",
    user_id: "u1",
    asset_id: "asset-cash",
    account_id: "acc-2",
    transaction_type: "buy",
    quantity: 18000,
    price_per_unit: 1,
    total_value: 18000,
    date: "2024-02-01T00:00:00Z",
    asset: {
      id: "asset-cash",
      name: "Chase Checking",
      symbol: null,
      category: "cash",
    },
    account: { id: "acc-2", name: "Chase", account_type: "bank" },
  },
];

describe("AssetDetailDialog", () => {
  beforeEach(() => {
    vi.mocked(useTransactions).mockReturnValue({
      data: mockTransactions,
      isLoading: false,
    } as ReturnType<typeof useTransactions>);
  });

  it("renders the asset name in the title", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText("Bitcoin")).toBeInTheDocument();
  });

  it("computes and displays cost basis correctly", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText("$19,500.00")).toBeInTheDocument();
  });

  it("computes and displays unrealized P&L correctly", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText(/\+\$10,500\.00 \(\+53\.85%\)/)).toBeInTheDocument();
  });

  it("shows only transactions for this asset", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getAllByRole("row").length).toBe(3);
  });

  it("shows account name in transaction rows", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getAllByText("Coinbase").length).toBeGreaterThan(0);
  });

  it("hides quantity, avg cost, P&L, and cost basis for cash category", () => {
    render(
      <AssetDetailDialog
        holding={mockCashHolding}
        category="cash"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.queryByText("Quantity")).not.toBeInTheDocument();
    expect(screen.queryByText("Avg Cost / Unit")).not.toBeInTheDocument();
    expect(screen.queryByText("Unrealized P&L")).not.toBeInTheDocument();
    expect(screen.queryByText("Cost Basis")).not.toBeInTheDocument();
    expect(screen.getByText("Current Value")).toBeInTheDocument();
    expect(screen.getByText("Last Transaction")).toBeInTheDocument();
  });

  it("hides quantity, avg cost, and P&L for real estate but still shows cost basis", () => {
    const reTx: EnrichedTransaction = {
      id: "tx-re",
      user_id: "u1",
      asset_id: "asset-re",
      account_id: "acc-1",
      transaction_type: "buy",
      quantity: 1,
      price_per_unit: 400000,
      total_value: 400000,
      date: "2023-01-01T00:00:00Z",
      asset: {
        id: "asset-re",
        name: "Oak Street Condo",
        symbol: null,
        category: "realEstate",
      },
      account: { id: "acc-1", name: "Self", account_type: "other" },
    };
    vi.mocked(useTransactions).mockReturnValue({
      data: [...mockTransactions, reTx],
      isLoading: false,
    } as ReturnType<typeof useTransactions>);

    render(
      <AssetDetailDialog
        holding={mockRealEstateHolding}
        category="realEstate"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.queryByText("Quantity")).not.toBeInTheDocument();
    expect(screen.queryByText("Avg Cost / Unit")).not.toBeInTheDocument();
    expect(screen.queryByText("Unrealized P&L")).not.toBeInTheDocument();
    expect(screen.getByText("Cost Basis")).toBeInTheDocument();
    expect(screen.getByText("Current Value")).toBeInTheDocument();
  });

  it("shows at most five recent transactions for an asset", () => {
    const many: EnrichedTransaction[] = Array.from({ length: 6 }, (_, i) => ({
      id: `tx-multi-${i}`,
      user_id: "u1",
      asset_id: "asset-1",
      account_id: "acc-1",
      transaction_type: "buy" as const,
      quantity: 0.01,
      price_per_unit: 40000 + i * 1000,
      total_value: 400 + i * 10,
      date: new Date(2024, 0, 15 - i).toISOString(),
      asset: { id: "asset-1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
      account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
    }));
    vi.mocked(useTransactions).mockReturnValue({
      data: many,
      isLoading: false,
    } as ReturnType<typeof useTransactions>);

    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    const table = screen.getByRole("table");
    const bodyRows = table.querySelectorAll("tbody tr");
    expect(bodyRows.length).toBe(5);
  });
});

describe("HoldingsGrid click behavior", () => {
  beforeEach(() => {
    vi.mocked(useTransactions).mockReturnValue({
      data: mockTransactions,
      isLoading: false,
    } as ReturnType<typeof useTransactions>);
  });

  it("opens AssetDetailDialog when an asset row is clicked", async () => {
    const user = userEvent.setup();
    const grouped = {
      crypto: [
        {
          id: "asset-1",
          name: "Bitcoin",
          symbol: "BTC",
          quantity: 0.5,
          current_value: 30000,
        },
      ],
    };

    render(<HoldingsGrid grouped={grouped} totalNetWorth={30000} />);

    await user.click(screen.getByRole("button", { name: "View details for Bitcoin" }));
    expect(screen.getAllByText("Bitcoin").length).toBeGreaterThan(1);
  });
});
