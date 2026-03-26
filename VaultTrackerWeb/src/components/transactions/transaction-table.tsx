"use client";

import { useMemo, useState } from "react";
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
} from "@tanstack/react-table";
import { Pencil, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { Category, EnrichedTransaction } from "@/types/api";
import { formatCurrency, formatDate } from "@/lib/format";

const categories: Category[] = [
  "crypto",
  "stocks",
  "cash",
  "realEstate",
  "retirement",
];

export function TransactionTable({
  data,
  onEdit,
  onDelete,
}: {
  data: EnrichedTransaction[];
  onEdit: (row: EnrichedTransaction) => void;
  onDelete: (row: EnrichedTransaction) => void;
}) {
  const [sorting, setSorting] = useState<SortingState>([
    { id: "date", desc: true },
  ]);
  const [globalFilter, setGlobalFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState<string>("all");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [accountFilter, setAccountFilter] = useState<string>("all");

  const accountNames = useMemo(() => {
    const s = new Set<string>();
    data.forEach((r) => s.add(r.account.name));
    return Array.from(s).sort();
  }, [data]);

  const columns = useMemo<ColumnDef<EnrichedTransaction>[]>(
    () => [
      {
        accessorKey: "date",
        header: "Date",
        cell: ({ getValue }) => formatDate(String(getValue())),
      },
      {
        accessorKey: "transaction_type",
        header: "Type",
        cell: ({ getValue }) => String(getValue()),
      },
      {
        accessorFn: (r) => r.asset.name,
        id: "asset",
        header: "Asset",
      },
      {
        accessorFn: (r) => r.asset.symbol ?? "",
        id: "symbol",
        header: "Symbol",
      },
      {
        accessorFn: (r) => r.asset.category,
        id: "category",
        header: "Category",
      },
      {
        accessorFn: (r) => r.account.name,
        id: "account",
        header: "Account",
      },
      {
        accessorKey: "quantity",
        header: "Qty",
        cell: ({ getValue }) =>
          Number(getValue()).toLocaleString(undefined, {
            maximumFractionDigits: 6,
          }),
      },
      {
        accessorKey: "price_per_unit",
        header: "Price",
        cell: ({ getValue }) => formatCurrency(Number(getValue())),
      },
      {
        accessorKey: "total_value",
        header: "Total",
        cell: ({ getValue }) => formatCurrency(Number(getValue())),
      },
      {
        id: "actions",
        header: "",
        cell: ({ row }) => (
          <div className="flex justify-end gap-1">
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="size-8"
              onClick={() => onEdit(row.original)}
              aria-label="Edit"
            >
              <Pencil className="size-4" />
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="text-destructive size-8"
              onClick={() => onDelete(row.original)}
              aria-label="Delete"
            >
              <Trash2 className="size-4" />
            </Button>
          </div>
        ),
      },
    ],
    [onEdit, onDelete]
  );

  const filteredData = useMemo(() => {
    return data.filter((row) => {
      if (typeFilter !== "all" && row.transaction_type !== typeFilter) {
        return false;
      }
      if (categoryFilter !== "all" && row.asset.category !== categoryFilter) {
        return false;
      }
      if (accountFilter !== "all" && row.account.name !== accountFilter) {
        return false;
      }
      if (globalFilter.trim()) {
        const q = globalFilter.toLowerCase();
        if (!row.asset.name.toLowerCase().includes(q)) return false;
      }
      return true;
    });
  }, [data, typeFilter, categoryFilter, accountFilter, globalFilter]);

  const table = useReactTable({
    data: filteredData,
    columns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    initialState: { pagination: { pageSize: 20 } },
  });

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-2 md:flex-row md:flex-wrap md:items-center">
        <Input
          placeholder="Search asset…"
          value={globalFilter}
          onChange={(e) => setGlobalFilter(e.target.value)}
          className="md:max-w-xs"
        />
        <Select
          value={typeFilter}
          onValueChange={(v) => setTypeFilter(v ?? "all")}
        >
          <SelectTrigger className="md:w-36">
            <SelectValue placeholder="Type" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All types</SelectItem>
            <SelectItem value="buy">Buy</SelectItem>
            <SelectItem value="sell">Sell</SelectItem>
          </SelectContent>
        </Select>
        <Select
          value={categoryFilter}
          onValueChange={(v) => setCategoryFilter(v ?? "all")}
        >
          <SelectTrigger className="md:w-44">
            <SelectValue placeholder="Category" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All categories</SelectItem>
            {categories.map((c) => (
              <SelectItem key={c} value={c}>
                {c}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select
          value={accountFilter}
          onValueChange={(v) => setAccountFilter(v ?? "all")}
        >
          <SelectTrigger className="md:w-48">
            <SelectValue placeholder="Account" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All accounts</SelectItem>
            {accountNames.map((n) => (
              <SelectItem key={n} value={n}>
                {n}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((hg) => (
              <TableRow key={hg.id}>
                {hg.headers.map((h) => (
                  <TableHead key={h.id}>
                    {h.isPlaceholder ? null : (
                      <button
                        type="button"
                        className={
                          h.column.getCanSort()
                            ? "cursor-pointer select-none font-medium"
                            : ""
                        }
                        onClick={h.column.getToggleSortingHandler()}
                      >
                        {flexRender(
                          h.column.columnDef.header,
                          h.getContext()
                        )}
                        {{
                          asc: " ↑",
                          desc: " ↓",
                        }[h.column.getIsSorted() as string] ?? null}
                      </button>
                    )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow key={row.id}>
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(
                        cell.column.columnDef.cell,
                        cell.getContext()
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={columns.length}
                  className="text-muted-foreground h-24 text-center"
                >
                  No transactions match filters.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <div className="flex items-center justify-between gap-2">
        <p className="text-muted-foreground text-sm">
          Page {table.getState().pagination.pageIndex + 1} of{" "}
          {table.getPageCount() || 1}
        </p>
        <div className="flex gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={!table.getCanPreviousPage()}
            onClick={() => table.previousPage()}
          >
            Previous
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={!table.getCanNextPage()}
            onClick={() => table.nextPage()}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  );
}

export function downloadTransactionsCsv(rows: EnrichedTransaction[]) {
  const header = [
    "date",
    "type",
    "asset",
    "symbol",
    "category",
    "account",
    "quantity",
    "price",
    "total",
  ];
  const lines = [
    header.join(","),
    ...rows.map((r) =>
      [
        r.date,
        r.transaction_type,
        JSON.stringify(r.asset.name),
        r.asset.symbol ?? "",
        r.asset.category,
        JSON.stringify(r.account.name),
        r.quantity,
        r.price_per_unit,
        r.total_value,
      ].join(",")
    ),
  ];
  const blob = new Blob([lines.join("\n")], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "vaulttracker-transactions.csv";
  a.click();
  URL.revokeObjectURL(url);
}
