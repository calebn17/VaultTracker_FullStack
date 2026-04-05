import type { ComponentProps } from "react";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TransactionFormDialog } from "@/components/transactions/transaction-form";
import type { EnrichedTransaction } from "@/types/api";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn((_, cb: (u: unknown) => void) => {
    cb(null);
    return () => {};
  }),
  signInWithPopup: vi.fn(),
  signOut: vi.fn(),
}));

function getDialog() {
  return screen.getByRole("dialog");
}

function fieldByName(name: string) {
  const el = getDialog().querySelector(`[name="${name}"]`);
  if (!el) throw new Error(`No field [name="${name}"]`);
  return el as HTMLInputElement;
}

function openDialog(props: Partial<ComponentProps<typeof TransactionFormDialog>> = {}) {
  const onSubmit = vi.fn();
  render(
    <TransactionFormDialog
      open
      onOpenChange={() => {}}
      initial={null}
      title="Add transaction"
      onSubmit={onSubmit}
      {...props}
    />
  );
  return { onSubmit };
}

describe("TransactionFormDialog", () => {
  it("renders Symbol when category is crypto", () => {
    openDialog();
    expect(fieldByName("symbol")).toBeInTheDocument();
  });

  it("does not render Symbol when category is cash", async () => {
    const user = userEvent.setup();
    openDialog();
    const comboboxes = within(getDialog()).getAllByRole("combobox");
    await user.click(comboboxes[1]);
    await user.click(screen.getByRole("option", { name: /^Cash$/ }));

    await waitFor(() => {
      expect(getDialog().querySelector('[name="symbol"]')).not.toBeInTheDocument();
    });
  });

  it('shows quantity label "Amount ($)" for cash', async () => {
    const user = userEvent.setup();
    openDialog();
    const comboboxes = within(getDialog()).getAllByRole("combobox");
    await user.click(comboboxes[1]);
    await user.click(screen.getByRole("option", { name: /^Cash$/ }));

    await waitFor(() => {
      expect(within(getDialog()).getByText("Amount ($)")).toBeInTheDocument();
    });
  });

  it('shows quantity label "Quantity" for stocks', async () => {
    const user = userEvent.setup();
    openDialog();
    const comboboxes = within(getDialog()).getAllByRole("combobox");
    await user.click(comboboxes[1]);
    await user.click(screen.getByRole("option", { name: /^Stocks$/ }));

    await waitFor(() => {
      expect(within(getDialog()).getByText(/^Quantity$/)).toBeInTheDocument();
    });
  });

  it("hides price per unit for cash", async () => {
    const user = userEvent.setup();
    openDialog();
    const comboboxes = within(getDialog()).getAllByRole("combobox");
    await user.click(comboboxes[1]);
    await user.click(screen.getByRole("option", { name: /^Cash$/ }));

    await waitFor(() => {
      expect(getDialog().querySelector('[name="price_per_unit"]')).not.toBeInTheDocument();
    });
  });

  it('shows "Required" when asset name is empty on submit', async () => {
    const user = userEvent.setup();
    const { onSubmit } = openDialog();

    await user.clear(fieldByName("asset_name"));
    await user.type(fieldByName("symbol"), "BTC");
    await user.clear(fieldByName("quantity"));
    await user.type(fieldByName("quantity"), "1");
    await user.clear(fieldByName("price_per_unit"));
    await user.type(fieldByName("price_per_unit"), "1");
    await user.type(fieldByName("account_name"), "Acct");

    await user.click(within(getDialog()).getByRole("button", { name: /^Save$/ }));

    expect(await within(getDialog()).findByText("Required")).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it("calls onSubmit with trimmed symbol and ISO date for valid crypto form", async () => {
    const user = userEvent.setup();
    const { onSubmit } = openDialog();

    await user.clear(fieldByName("asset_name"));
    await user.type(fieldByName("asset_name"), "Bitcoin");
    await user.clear(fieldByName("symbol"));
    await user.type(fieldByName("symbol"), "  btc  ");
    await user.clear(fieldByName("quantity"));
    await user.type(fieldByName("quantity"), "2");
    await user.clear(fieldByName("price_per_unit"));
    await user.type(fieldByName("price_per_unit"), "10");
    await user.clear(fieldByName("account_name"));
    await user.type(fieldByName("account_name"), "Main");

    const dateInput = fieldByName("date");
    await user.clear(dateInput);
    await user.type(dateInput, "2024-03-10");

    await user.click(within(getDialog()).getByRole("button", { name: /^Save$/ }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalled());
    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        asset_name: "Bitcoin",
        symbol: "btc",
        quantity: 2,
        price_per_unit: 10,
        account_name: "Main",
        date: new Date("2024-03-10T12:00:00.000Z").toISOString(),
      })
    );
  });

  it("calls onOpenChange(false) after onSubmit resolves successfully", async () => {
    const user = userEvent.setup();
    const onOpenChange = vi.fn();
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(
      <TransactionFormDialog
        open
        onOpenChange={onOpenChange}
        initial={null}
        title="Add transaction"
        onSubmit={onSubmit}
      />
    );

    await user.clear(fieldByName("asset_name"));
    await user.type(fieldByName("asset_name"), "Bitcoin");
    await user.clear(fieldByName("symbol"));
    await user.type(fieldByName("symbol"), "btc");
    await user.clear(fieldByName("quantity"));
    await user.type(fieldByName("quantity"), "2");
    await user.clear(fieldByName("price_per_unit"));
    await user.type(fieldByName("price_per_unit"), "10");
    await user.clear(fieldByName("account_name"));
    await user.type(fieldByName("account_name"), "Main");

    const dateInput = fieldByName("date");
    await user.clear(dateInput);
    await user.type(dateInput, "2024-03-10");

    await user.click(within(getDialog()).getByRole("button", { name: /^Save$/ }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalled());
    await waitFor(() => expect(onOpenChange).toHaveBeenCalledWith(false));
  });

  it("does not call onOpenChange(false) when onSubmit rejects", async () => {
    const user = userEvent.setup();
    const onOpenChange = vi.fn();
    const onSubmit = vi.fn().mockRejectedValue(new Error("network"));
    render(
      <TransactionFormDialog
        open
        onOpenChange={onOpenChange}
        initial={null}
        title="Add transaction"
        onSubmit={onSubmit}
      />
    );

    await user.clear(fieldByName("asset_name"));
    await user.type(fieldByName("asset_name"), "Bitcoin");
    await user.clear(fieldByName("symbol"));
    await user.type(fieldByName("symbol"), "btc");
    await user.clear(fieldByName("quantity"));
    await user.type(fieldByName("quantity"), "2");
    await user.clear(fieldByName("price_per_unit"));
    await user.type(fieldByName("price_per_unit"), "10");
    await user.clear(fieldByName("account_name"));
    await user.type(fieldByName("account_name"), "Main");

    const dateInput = fieldByName("date");
    await user.clear(dateInput);
    await user.type(dateInput, "2024-03-10");

    await user.click(within(getDialog()).getByRole("button", { name: /^Save$/ }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalled());
    await Promise.resolve();
    await Promise.resolve();
    expect(onOpenChange).not.toHaveBeenCalledWith(false);
  });

  it("Cancel button calls onOpenChange(false)", async () => {
    const user = userEvent.setup();
    const onOpenChange = vi.fn();
    render(
      <TransactionFormDialog
        open
        onOpenChange={onOpenChange}
        initial={null}
        title="Add transaction"
        onSubmit={() => {}}
      />
    );

    await user.click(within(getDialog()).getByRole("button", { name: /cancel/i }));

    expect(onOpenChange).toHaveBeenCalledWith(false);
    expect(onOpenChange).toHaveBeenCalledTimes(1);
  });

  it("Save button is disabled and shows 'Saving…' when pending is true", () => {
    render(
      <TransactionFormDialog
        open
        onOpenChange={() => {}}
        initial={null}
        title="Add transaction"
        onSubmit={() => {}}
        pending
      />
    );

    const saveBtn = within(getDialog()).getByRole("button", { name: /saving/i });
    expect(saveBtn).toBeDisabled();
    // Verify the label changed from "Save" to "Saving…" — not just disabled
    expect(saveBtn).toHaveTextContent("Saving…");
  });

  it("pre-fills fields from an existing transaction", () => {
    const tx: EnrichedTransaction = {
      id: "t1",
      user_id: "u1",
      asset_id: "a1",
      account_id: "c1",
      transaction_type: "buy",
      quantity: 3,
      price_per_unit: 12,
      total_value: 36,
      date: "2024-02-01T00:00:00Z",
      asset: {
        id: "a1",
        name: "Gold",
        symbol: "XAU",
        category: "stocks",
      },
      account: {
        id: "c1",
        name: "IRA",
        account_type: "retirement",
      },
    };

    render(
      <TransactionFormDialog
        open
        onOpenChange={() => {}}
        initial={tx}
        title="Edit"
        onSubmit={() => {}}
      />
    );

    expect(fieldByName("asset_name").value).toBe("Gold");
    expect(fieldByName("symbol").value).toBe("XAU");
    expect(fieldByName("quantity").valueAsNumber).toBe(3);
    expect(fieldByName("price_per_unit").valueAsNumber).toBe(12);
    expect(fieldByName("account_name").value).toBe("IRA");
    expect(fieldByName("date").value).toBe("2024-02-01");
  });
});
