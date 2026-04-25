"use client";

import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate } from "@/lib/format";
import type { AccountGridViewProps } from "./account-grid";

export function AccountListView({
  accounts,
  txCountByAccount,
  onEdit,
  onDelete,
}: AccountGridViewProps) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Name</TableHead>
          <TableHead>Type</TableHead>
          <TableHead>Created</TableHead>
          <TableHead>Transactions</TableHead>
          <TableHead className="text-right">Actions</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {accounts.map((a) => (
          <TableRow key={a.id}>
            <TableCell className="font-medium">{a.name}</TableCell>
            <TableCell>{a.account_type}</TableCell>
            <TableCell className="text-muted-foreground">{formatDate(a.created_at)}</TableCell>
            <TableCell>{txCountByAccount.get(a.id) ?? 0}</TableCell>
            <TableCell className="text-right">
              <div className="flex justify-end gap-2">
                <Button type="button" variant="outline" size="sm" onClick={() => onEdit(a)}>
                  Edit
                </Button>
                <Button type="button" variant="destructive" size="sm" onClick={() => onDelete(a)}>
                  Delete
                </Button>
              </div>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
