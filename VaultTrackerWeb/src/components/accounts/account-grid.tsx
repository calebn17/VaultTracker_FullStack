"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { formatDate } from "@/lib/format";
import type { AccountResponse } from "@/types/api";

export type AccountGridViewProps = {
  accounts: AccountResponse[];
  txCountByAccount: Map<string, number>;
  onEdit: (a: AccountResponse) => void;
  onDelete: (a: AccountResponse) => void;
};

export function AccountGridView({
  accounts,
  txCountByAccount,
  onEdit,
  onDelete,
}: AccountGridViewProps) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {accounts.map((a) => (
        <Card key={a.id}>
          <CardHeader>
            <CardTitle className="text-lg">{a.name}</CardTitle>
            <CardDescription>{a.account_type}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p className="text-muted-foreground">Created {formatDate(a.created_at)}</p>
            <p>Transactions: {txCountByAccount.get(a.id) ?? 0}</p>
            <div className="flex gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => onEdit(a)}>
                Edit
              </Button>
              <Button type="button" variant="destructive" size="sm" onClick={() => onDelete(a)}>
                Delete
              </Button>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
