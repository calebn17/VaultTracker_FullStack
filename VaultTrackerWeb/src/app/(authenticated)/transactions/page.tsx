"use client";

import { useState } from "react";
import { toast } from "sonner";
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
import { TransactionTable, downloadTransactionsCsv } from "@/components/transactions/transaction-table";
import { TransactionFormDialog } from "@/components/transactions/transaction-form";
import {
  useTransactions,
  useCreateTransaction,
  useUpdateTransaction,
  useDeleteTransaction,
} from "@/lib/queries/use-transactions";
import type { EnrichedTransaction } from "@/types/api";

export default function TransactionsPage() {
  const { data, isLoading, error } = useTransactions();
  const createTx = useCreateTransaction();
  const updateTx = useUpdateTransaction();
  const deleteTx = useDeleteTransaction();

  const [addOpen, setAddOpen] = useState(false);
  const [editRow, setEditRow] = useState<EnrichedTransaction | null>(null);
  const [deleteRow, setDeleteRow] = useState<EnrichedTransaction | null>(null);

  const rows = data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Transactions</h1>
        <div className="flex flex-wrap gap-2">
          <Button type="button" variant="outline" onClick={() => downloadTransactionsCsv(rows)}>
            Export CSV
          </Button>
          <Button type="button" onClick={() => setAddOpen(true)}>
            Add transaction
          </Button>
        </div>
      </div>

      {error ? (
        <p className="text-destructive text-sm">
          {error instanceof Error ? error.message : "Failed to load"}
        </p>
      ) : null}

      {isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : (
        <TransactionTable
          data={rows}
          onEdit={(r) => setEditRow(r)}
          onDelete={(r) => setDeleteRow(r)}
        />
      )}

      <TransactionFormDialog
        open={addOpen}
        onOpenChange={setAddOpen}
        initial={null}
        title="Add transaction"
        pending={createTx.isPending}
        onSubmit={(payload) => {
          createTx.mutate(payload, {
            onSuccess: () => {
              toast.success("Transaction added");
              setAddOpen(false);
            },
            onError: (e) =>
              toast.error(e instanceof Error ? e.message : "Create failed"),
          });
        }}
      />

      <TransactionFormDialog
        open={!!editRow}
        onOpenChange={(o) => !o && setEditRow(null)}
        initial={editRow}
        title="Edit transaction"
        pending={updateTx.isPending}
        onSubmit={(payload) => {
          if (!editRow) return;
          updateTx.mutate(
            { id: editRow.id, data: payload },
            {
              onSuccess: () => {
                toast.success("Transaction updated");
                setEditRow(null);
              },
              onError: (e) =>
                toast.error(e instanceof Error ? e.message : "Update failed"),
            }
          );
        }}
      />

      <AlertDialog open={!!deleteRow} onOpenChange={(o) => !o && setDeleteRow(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete transaction?</AlertDialogTitle>
            <AlertDialogDescription>
              This reverses the effect on the linked asset and cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={() => {
                if (!deleteRow) return;
                deleteTx.mutate(deleteRow.id, {
                  onSuccess: () => {
                    toast.success("Deleted");
                    setDeleteRow(null);
                  },
                  onError: (e) =>
                    toast.error(e instanceof Error ? e.message : "Delete failed"),
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
