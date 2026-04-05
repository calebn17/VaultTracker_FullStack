"use client";

import { useMemo, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
import { AccountFormDialog } from "@/components/accounts/account-form";
import {
  useAccounts,
  useCreateAccount,
  useUpdateAccount,
  useDeleteAccount,
} from "@/lib/queries/use-accounts";
import { useTransactions } from "@/lib/queries/use-transactions";
import { formatDate } from "@/lib/format";
import type { AccountResponse } from "@/types/api";

export default function AccountsPage() {
  const { data, isLoading, error } = useAccounts();
  const { data: txs } = useTransactions();
  const createAcc = useCreateAccount();
  const updateAcc = useUpdateAccount();
  const deleteAcc = useDeleteAccount();

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
        <Button type="button" onClick={() => setAddOpen(true)}>
          Add account
        </Button>
      </div>

      {error ? <p className="text-destructive text-sm">Failed to load accounts.</p> : null}

      {isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {rows.map((a) => (
            <Card key={a.id}>
              <CardHeader>
                <CardTitle className="text-lg">{a.name}</CardTitle>
                <CardDescription>{a.account_type}</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3 text-sm">
                <p className="text-muted-foreground">Created {formatDate(a.created_at)}</p>
                <p>Transactions: {txCountByAccount.get(a.id) ?? 0}</p>
                <div className="flex gap-2">
                  <Button type="button" variant="outline" size="sm" onClick={() => setEdit(a)}>
                    Edit
                  </Button>
                  <Button type="button" variant="destructive" size="sm" onClick={() => setDel(a)}>
                    Delete
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
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
