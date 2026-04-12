"use client";

import type { FireTargets } from "@/types/api";
import { formatCurrency } from "@/lib/format";

const ROWS: { key: keyof FireTargets; label: string }[] = [
  { key: "leanFire", label: "Lean FIRE" },
  { key: "fire", label: "Regular FIRE" },
  { key: "fatFire", label: "Fat FIRE" },
];

export function FireTargetsTable({ targets }: { targets: FireTargets }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-border" data-slot="fire-targets-table">
      <table className="w-full text-left text-sm">
        <thead className="bg-muted/50 border-b text-[11px] tracking-wide uppercase">
          <tr>
            <th className="px-3 py-2 font-medium">Type</th>
            <th className="px-3 py-2 font-medium">Target amount</th>
            <th className="px-3 py-2 font-medium">Years</th>
            <th className="px-3 py-2 font-medium">Target age</th>
          </tr>
        </thead>
        <tbody>
          {ROWS.map(({ key, label }) => {
            const t = targets[key];
            return (
              <tr key={key} className="border-border/80 border-b last:border-0">
                <td className="px-3 py-2 font-medium">{label}</td>
                <td className="text-muted-foreground px-3 py-2 font-mono tabular-nums">
                  {formatCurrency(t.targetAmount)}
                </td>
                <td className="text-muted-foreground px-3 py-2 font-mono tabular-nums">
                  {t.yearsToTarget ?? "—"}
                </td>
                <td className="text-muted-foreground px-3 py-2 font-mono tabular-nums">
                  {t.targetAge ?? "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
