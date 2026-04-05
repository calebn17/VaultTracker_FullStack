"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import type { Category, CategoryTotals } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";

export const CATEGORY_ORDER: Category[] = ["crypto", "stocks", "cash", "realEstate", "retirement"];

export const CATEGORY_BAR_COLORS: Record<Category, string> = {
  crypto: "bg-chart-1",
  stocks: "bg-chart-2",
  cash: "bg-chart-3",
  realEstate: "bg-chart-4",
  retirement: "bg-chart-5",
};

export const CATEGORY_LABELS: Record<Category, string> = {
  crypto: "Crypto",
  stocks: "Stocks",
  cash: "Cash",
  realEstate: "Real Estate",
  retirement: "Retirement",
};

function useSegmentTooltipAnchor() {
  const anchorRef = useRef<HTMLDivElement | null>(null);
  const [hoveredKey, setHoveredKey] = useState<Category | null>(null);
  const [tipPos, setTipPos] = useState({ x: 0, y: 0 });

  const syncPosition = () => {
    const el = anchorRef.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    setTipPos({
      x: rect.left + rect.width / 2,
      y: rect.top,
    });
  };

  useEffect(() => {
    if (!hoveredKey) return;
    const onMove = () => syncPosition();
    window.addEventListener("scroll", onMove, true);
    window.addEventListener("resize", onMove);
    return () => {
      window.removeEventListener("scroll", onMove, true);
      window.removeEventListener("resize", onMove);
    };
  }, [hoveredKey]);

  return {
    hoveredKey,
    tipPos,
    onSegmentEnter: (key: Category, el: HTMLDivElement) => {
      anchorRef.current = el;
      setHoveredKey(key);
      const rect = el.getBoundingClientRect();
      setTipPos({
        x: rect.left + rect.width / 2,
        y: rect.top,
      });
    },
    onSegmentLeave: () => {
      anchorRef.current = null;
      setHoveredKey(null);
    },
  };
}

export function CategoryBar({
  totals,
  total,
  loading,
  showLegend = true,
}: {
  totals: CategoryTotals | undefined;
  total: number;
  loading?: boolean;
  showLegend?: boolean;
}) {
  const tooltip = useSegmentTooltipAnchor();

  if (loading || !totals) {
    return (
      <div className="bg-muted h-4 w-full overflow-hidden rounded-full">
        <div className="bg-muted-foreground/20 h-full w-full animate-pulse" />
      </div>
    );
  }

  const tooltipNode =
    tooltip.hoveredKey &&
    typeof document !== "undefined" &&
    createPortal(
      <div
        role="tooltip"
        className="pointer-events-none fixed z-[100] min-w-[8rem] rounded-md bg-popover px-2.5 py-1.5 text-xs text-popover-foreground shadow-md ring-1 ring-foreground/10 animate-in fade-in-0 zoom-in-95"
        style={{
          left: tooltip.tipPos.x,
          top: tooltip.tipPos.y,
          transform: "translate(-50%, calc(-100% - 6px))",
        }}
      >
        <div className="font-medium">{CATEGORY_LABELS[tooltip.hoveredKey]}</div>
        <div className="text-muted-foreground tabular-nums">
          {formatCurrency(totals[tooltip.hoveredKey])}
        </div>
      </div>,
      document.body
    );

  return (
    <div>
      {tooltipNode}
      <div className="flex h-4 w-full overflow-hidden rounded-full">
        {CATEGORY_ORDER.map((key) => {
          const v = totals[key];
          const pct = total > 0 ? (v / total) * 100 : 0;
          if (pct <= 0) return null;
          return (
            <div
              key={key}
              className={cn(
                CATEGORY_BAR_COLORS[key],
                "h-full min-w-0 cursor-default transition-all"
              )}
              style={{ width: `${pct}%` }}
              aria-label={`${CATEGORY_LABELS[key]}: ${formatCurrency(v)}`}
              onMouseEnter={(e) => tooltip.onSegmentEnter(key, e.currentTarget)}
              onMouseLeave={tooltip.onSegmentLeave}
            />
          );
        })}
      </div>
      {showLegend ? (
        <div className="mt-2 flex flex-wrap gap-3 text-xs">
          {CATEGORY_ORDER.map((key) => (
            <span key={key} className="text-muted-foreground flex items-center gap-1">
              <span className={cn("size-2 rounded-full", CATEGORY_BAR_COLORS[key])} />
              {CATEGORY_LABELS[key]}: {formatCurrency(totals[key])}
            </span>
          ))}
        </div>
      ) : null}
    </div>
  );
}
