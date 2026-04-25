"use client";

import { LayoutGrid, List } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { AccountFormDialog } from "@/components/accounts/account-form";
import { AccountGridView } from "@/components/accounts/account-grid";
import { AccountListView } from "@/components/accounts/account-list";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  useAccounts,
  useCreateAccount,
  useUpdateAccount,
  useDeleteAccount,
} from "@/lib/queries/use-accounts";
import { useTransactions } from "@/lib/queries/use-transactions";
import { cn } from "@/lib/utils";
import type { AccountResponse } from "@/types/api";

export default function AccountsPage() {
  const { data, isLoading, error } = useAccounts();
  const { data: txs } = useTransactions();
  const createAcc = useCreateAccount();
  const updateAcc = useUpdateAccount();
  const deleteAcc = useDeleteAccount();

  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");
  const [addOpen, setAddOpen] = useState(false);
  const [edit, setEdit] = useState<AccountResponse | null>(null);
  const [del, setDel] = useState<AccountResponse | null>(null);

  const txCountByAccount = useMemo(() => {
    const m = new Map<string, number>();
    (txs ?? []).forEach((t) => {
      m.set(t.account_id, (m.get(t.account_id) ?? 0) + 1);
    });
    return m;
  }, [txs]);

  const rows = data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="font-heading text-xl font-semibold tracking-tight">Accounts</h1>
        <div className="flex flex-wrap items-center gap-2">
          <div
            className="flex items-center gap-1 rounded-md border p-0.5"
            role="group"
            aria-label="Account layout"
          >
            <button
              type="button"
              aria-pressed={viewMode === "grid"}
              aria-label="Grid view"
              className={cn(
                "rounded p-1.5 transition-colors",
                viewMode === "grid"
                  ? "bg-card text-primary"
                  : "text-muted-foreground hover:text-foreground"
              )}
              onClick={() => setViewMode("grid")}
            >
              <LayoutGrid className="size-4" aria-hidden />
            </button>
            <button
              type="button"
              aria-pressed={viewMode === "list"}
              aria-label="List view"
              className={cn(
                "rounded p-1.5 transition-colors",
                viewMode === "list"
                  ? "bg-card text-primary"
                  : "text-muted-foreground hover:text-foreground"
              )}
              onClick={() => setViewMode("list")}
            >
              <List className="size-4" aria-hidden />
            </button>
          </div>
          <Button type="button" onClick={() => setAddOpen(true)}>
            Add account
          </Button>
        </div>
      </div>

      {error ? <p className="text-destructive text-sm">Failed to load accounts.</p> : null}

      {isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : viewMode === "grid" ? (
        <AccountGridView
          accounts={rows}
          txCountByAccount={txCountByAccount}
          onEdit={setEdit}
          onDelete={setDel}
        />
      ) : (
        <AccountListView
          accounts={rows}
          txCountByAccount={txCountByAccount}
          onEdit={setEdit}
          onDelete={setDel}
        />
      )}

      {!isLoading && rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No accounts yet.</p>
      ) : null}

      <AccountFormDialog
        open={addOpen}
        onOpenChange={setAddOpen}
        initial={null}
        title="Add account"
        pending={createAcc.isPending}
        onSubmit={(v) => {
          createAcc.mutate(v, {
            onSuccess: () => {
              toast.success("Account created");
              setAddOpen(false);
            },
            onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
          });
        }}
      />

      <AccountFormDialog
        open={!!edit}
        onOpenChange={(o) => !o && setEdit(null)}
        initial={edit}
        title="Edit account"
        pending={updateAcc.isPending}
        onSubmit={(v) => {
          if (!edit) return;
          updateAcc.mutate(
            { id: edit.id, data: v },
            {
              onSuccess: () => {
                toast.success("Updated");
                setEdit(null);
              },
              onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
            }
          );
        }}
      />

      <AlertDialog open={!!del} onOpenChange={(o) => !o && setDel(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete account?</AlertDialogTitle>
            <AlertDialogDescription>
              This may remove linked transactions depending on server cascade rules. This action
              cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (!del) return;
                deleteAcc.mutate(del.id, {
                  onSuccess: () => {
                    toast.success("Account deleted");
                    setDel(null);
                  },
                  onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
                });
              }}
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
