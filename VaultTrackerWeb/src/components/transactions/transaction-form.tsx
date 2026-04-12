"use client";

import { useEffect, useMemo } from "react";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
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
import { cn } from "@/lib/utils";

const formLabel = "text-[10px] font-medium uppercase tracking-[0.1em] text-muted-foreground";

const controlClass =
  "min-h-10 rounded-lg border-border bg-secondary px-3.5 py-2.5 text-[13px] shadow-none focus-visible:border-primary/40 focus-visible:ring-3 focus-visible:ring-primary/30 dark:bg-secondary dark:focus-visible:ring-primary/40";

const selectTriggerClass =
  "h-auto min-h-10 w-full justify-between rounded-lg border-border bg-secondary px-3.5 py-2.5 text-[13px] shadow-none focus-visible:border-primary/40 focus-visible:ring-3 focus-visible:ring-primary/30 dark:bg-secondary data-[size=default]:h-auto dark:focus-visible:ring-primary/40";

const TRANSACTION_TYPE_LABELS: Record<"buy" | "sell", string> = {
  buy: "Buy",
  sell: "Sell",
};

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
  }) => void | Promise<void>;
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

  const watchedCategory = useWatch({ control: form.control, name: "category" });
  const watchedTransactionType = useWatch({ control: form.control, name: "transaction_type" });
  const watchedAccountType = useWatch({ control: form.control, name: "account_type" });
  const category = watchedCategory ?? defaults.category;
  const transactionType = watchedTransactionType ?? defaults.transaction_type;
  const accountType = watchedAccountType ?? defaults.account_type;

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

  const handleSubmit = form.handleSubmit(async (values) => {
    const cashLike = isCashLike(values.category);
    const payload = {
      transaction_type: values.transaction_type,
      category: values.category,
      asset_name: values.asset_name,
      symbol: needsSymbol(values.category) ? values.symbol?.trim() : undefined,
      quantity: values.quantity,
      price_per_unit: cashLike ? 1 : values.price_per_unit,
      account_name: values.account_name,
      account_type: values.account_type,
      date: new Date(values.date + "T12:00:00.000Z").toISOString(),
    };
    try {
      await Promise.resolve(onSubmit(payload));
      onOpenChange(false);
    } catch {
      /* Parent handles errors (e.g. toast); keep dialog open */
    }
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        overlayClassName="bg-black/70 supports-backdrop-filter:backdrop-blur-md"
        closeButtonClassName="top-6 right-6"
        className={cn(
          "max-h-[90vh] gap-0 overflow-y-auto rounded-[20px] border-white/12 p-8 pt-10 shadow-[0_40px_80px_rgba(0,0,0,0.6)] ring-white/12 sm:max-w-[460px]",
          "data-open:duration-200 data-open:zoom-in-95 data-closed:duration-150"
        )}
      >
        <DialogHeader className="gap-1.5 space-y-0 text-left">
          <DialogTitle className="font-serif text-[26px] font-normal leading-tight tracking-tight">
            {title}
          </DialogTitle>
          <DialogDescription className="text-[11px] leading-snug text-muted-foreground">
            {initial
              ? "Update this transaction and linked account details."
              : "Add a buy or sell and link it to an account."}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="mt-7 grid grid-cols-2 gap-x-4 gap-y-4">
          <div className="flex flex-col gap-1.5">
            <span className={formLabel}>Type</span>
            <Select
              value={transactionType}
              onValueChange={(v) => form.setValue("transaction_type", v as "buy" | "sell")}
            >
              <SelectTrigger className={selectTriggerClass}>
                <SelectValue>{TRANSACTION_TYPE_LABELS[transactionType]}</SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="buy">Buy</SelectItem>
                <SelectItem value="sell">Sell</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="flex flex-col gap-1.5">
            <span className={formLabel}>Category</span>
            <Select
              value={category}
              onValueChange={(v) => form.setValue("category", v as Category)}
            >
              <SelectTrigger className={selectTriggerClass}>
                <SelectValue placeholder="Category">{CATEGORY_LABELS[category]}</SelectValue>
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

          <div className="col-span-2 flex flex-col gap-1.5">
            <span className={formLabel}>Asset name</span>
            <Input className={controlClass} {...form.register("asset_name")} />
            {form.formState.errors.asset_name ? (
              <p className="text-destructive text-xs">{form.formState.errors.asset_name.message}</p>
            ) : null}
          </div>

          {needsSymbol(category) ? (
            <div className="col-span-2 flex flex-col gap-1.5">
              <span className={formLabel}>Symbol</span>
              <Input className={controlClass} {...form.register("symbol")} />
              {form.formState.errors.symbol ? (
                <p className="text-destructive text-xs">{form.formState.errors.symbol.message}</p>
              ) : null}
            </div>
          ) : null}

          <div
            className={cn(
              "flex flex-col gap-1.5",
              isCashLike(category) ? "col-span-2" : "col-span-2 sm:col-span-1"
            )}
          >
            <span className={formLabel}>{isCashLike(category) ? "Amount ($)" : "Quantity"}</span>
            <Input
              className={controlClass}
              type="number"
              step="any"
              {...form.register("quantity", { valueAsNumber: true })}
            />
            {form.formState.errors.quantity ? (
              <p className="text-destructive text-xs">{form.formState.errors.quantity.message}</p>
            ) : null}
          </div>

          {!isCashLike(category) ? (
            <div className="col-span-2 flex flex-col gap-1.5 sm:col-span-1">
              <span className={formLabel}>Price per unit</span>
              <Input
                className={controlClass}
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

          <div className="col-span-2 flex flex-col gap-1.5 sm:col-span-1">
            <span className={formLabel}>Account name</span>
            <Input className={controlClass} {...form.register("account_name")} />
          </div>

          <div className="col-span-2 flex flex-col gap-1.5 sm:col-span-1">
            <span className={formLabel}>Account type</span>
            <Select
              value={accountType}
              onValueChange={(v) =>
                form.setValue("account_type", v as import("@/types/api").AccountType)
              }
            >
              <SelectTrigger className={selectTriggerClass}>
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

          <div className="col-span-2 flex flex-col gap-1.5">
            <span className={formLabel}>Date</span>
            <Input className={controlClass} type="date" {...form.register("date")} />
          </div>

          <div className="col-span-2 mt-2 flex gap-2.5">
            <Button
              type="button"
              variant="outline"
              className="flex-1 border-border bg-transparent py-2.5 text-xs text-muted-foreground hover:border-white/20 hover:bg-transparent hover:text-foreground dark:hover:bg-transparent"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={pending}
              className="flex-[2] bg-primary py-2.5 text-xs font-medium text-primary-foreground hover:bg-[#d9ff6e] dark:hover:bg-[#d9ff6e]"
            >
              {pending ? "Saving…" : "Save"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
