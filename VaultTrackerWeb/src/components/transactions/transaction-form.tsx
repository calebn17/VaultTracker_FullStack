"use client";

import { useEffect, useMemo } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { Category, EnrichedTransaction } from "@/types/api";
import { CATEGORY_LABELS } from "@/components/dashboard/category-bar";
import { ACCOUNT_TYPES_BY_CATEGORY } from "@/lib/account-types";
import {
  transactionSchema,
  type TransactionFormValues,
  needsSymbol,
  isCashLike,
  toFormDefaults,
} from "@/lib/transaction-schema";

export function TransactionFormDialog({
  open,
  onOpenChange,
  initial,
  onSubmit,
  pending,
  title,
  defaultCategory,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  initial: EnrichedTransaction | null;
  /** When adding (no `initial`), pre-select this category in the form. */
  defaultCategory?: Category;
  onSubmit: (payload: {
    transaction_type: "buy" | "sell";
    category: Category;
    asset_name: string;
    symbol?: string;
    quantity: number;
    price_per_unit: number;
    account_name: string;
    account_type: import("@/types/api").AccountType;
    date?: string;
  }) => void;
  pending?: boolean;
  title: string;
}) {
  const defaults = useMemo(
    () => toFormDefaults(initial, defaultCategory),
    [initial, defaultCategory]
  );

  const form = useForm<TransactionFormValues>({
    resolver: zodResolver(transactionSchema),
    defaultValues: defaults,
  });

  useEffect(() => {
    if (open) {
      form.reset(toFormDefaults(initial, defaultCategory));
    }
  }, [open, initial, defaultCategory, form]);

  const category = form.watch("category");

  useEffect(() => {
    const allowed = ACCOUNT_TYPES_BY_CATEGORY[category];
    const cur = form.getValues("account_type");
    if (!allowed.includes(cur)) {
      form.setValue("account_type", allowed[0]);
    }
  }, [category, form]);

  useEffect(() => {
    if (isCashLike(category)) {
      form.setValue("price_per_unit", 1);
    }
  }, [category, form]);

  const handleSubmit = form.handleSubmit((values) => {
    const cashLike = isCashLike(values.category);
    const payload = {
      transaction_type: values.transaction_type,
      category: values.category,
      asset_name: values.asset_name,
      symbol: needsSymbol(values.category)
        ? values.symbol?.trim()
        : undefined,
      quantity: values.quantity,
      price_per_unit: cashLike ? 1 : values.price_per_unit,
      account_name: values.account_name,
      account_type: values.account_type,
      date: new Date(values.date + "T12:00:00.000Z").toISOString(),
    };
    onSubmit(payload);
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid gap-2">
            <Label>Type</Label>
            <Select
              value={form.watch("transaction_type")}
              onValueChange={(v) =>
                form.setValue("transaction_type", v as "buy" | "sell")
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="buy">Buy</SelectItem>
                <SelectItem value="sell">Sell</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-2">
            <Label>Category</Label>
            <Select
              value={form.watch("category")}
              onValueChange={(v) =>
                form.setValue("category", v as Category)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Category">
                  {CATEGORY_LABELS[form.watch("category")]}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="crypto">Crypto</SelectItem>
                <SelectItem value="stocks">Stocks</SelectItem>
                <SelectItem value="cash">Cash</SelectItem>
                <SelectItem value="realEstate">Real Estate</SelectItem>
                <SelectItem value="retirement">Retirement</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-2">
            <Label>Asset name</Label>
            <Input {...form.register("asset_name")} />
            {form.formState.errors.asset_name ? (
              <p className="text-destructive text-xs">
                {form.formState.errors.asset_name.message}
              </p>
            ) : null}
          </div>

          {needsSymbol(category) ? (
            <div className="grid gap-2">
              <Label>Symbol</Label>
              <Input {...form.register("symbol")} />
              {form.formState.errors.symbol ? (
                <p className="text-destructive text-xs">
                  {form.formState.errors.symbol.message}
                </p>
              ) : null}
            </div>
          ) : null}

          <div className="grid gap-2">
            <Label>
              {isCashLike(category) ? "Amount ($)" : "Quantity"}
            </Label>
            <Input
              type="number"
              step="any"
              {...form.register("quantity", { valueAsNumber: true })}
            />
            {form.formState.errors.quantity ? (
              <p className="text-destructive text-xs">
                {form.formState.errors.quantity.message}
              </p>
            ) : null}
          </div>

          {!isCashLike(category) ? (
            <div className="grid gap-2">
              <Label>Price per unit</Label>
              <Input
                type="number"
                step="any"
                {...form.register("price_per_unit", { valueAsNumber: true })}
              />
              {form.formState.errors.price_per_unit ? (
                <p className="text-destructive text-xs">
                  {form.formState.errors.price_per_unit.message}
                </p>
              ) : null}
            </div>
          ) : null}

          <div className="grid gap-2">
            <Label>Account name</Label>
            <Input {...form.register("account_name")} />
          </div>

          <div className="grid gap-2">
            <Label>Account type</Label>
            <Select
              value={form.watch("account_type")}
              onValueChange={(v) =>
                form.setValue(
                  "account_type",
                  v as import("@/types/api").AccountType
                )
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ACCOUNT_TYPES_BY_CATEGORY[category].map((t) => (
                  <SelectItem key={t} value={t}>
                    {t}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid gap-2">
            <Label>Date</Label>
            <Input type="date" {...form.register("date")} />
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
