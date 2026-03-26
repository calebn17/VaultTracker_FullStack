"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
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
import type { AccountResponse, AccountType } from "@/types/api";

const types: AccountType[] = [
  "cryptoExchange",
  "brokerage",
  "bank",
  "retirement",
  "other",
];

const schema = z.object({
  name: z.string().min(1),
  account_type: z.enum([
    "cryptoExchange",
    "brokerage",
    "bank",
    "retirement",
    "other",
  ]),
});

type FormValues = z.infer<typeof schema>;

export function AccountFormDialog({
  open,
  onOpenChange,
  initial,
  onSubmit,
  pending,
  title,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  initial: AccountResponse | null;
  onSubmit: (v: { name: string; account_type: AccountType }) => void;
  pending?: boolean;
  title: string;
}) {
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: initial?.name ?? "",
      account_type: initial?.account_type ?? "bank",
    },
  });

  useEffect(() => {
    if (open) {
      form.reset({
        name: initial?.name ?? "",
        account_type: initial?.account_type ?? "bank",
      });
    }
  }, [open, initial, form]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        <form
          onSubmit={form.handleSubmit(onSubmit)}
          className="space-y-4"
        >
          <div className="grid gap-2">
            <Label>Name</Label>
            <Input {...form.register("name")} />
          </div>
          <div className="grid gap-2">
            <Label>Type</Label>
            <Select
              value={form.watch("account_type")}
              onValueChange={(v) =>
                form.setValue("account_type", v as AccountType)
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {types.map((t) => (
                  <SelectItem key={t} value={t}>
                    {t}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
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
