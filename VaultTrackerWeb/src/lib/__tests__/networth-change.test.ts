import { describe, it, expect } from "vitest";
import { computeApproxMonthChange } from "@/lib/networth-change";

describe("computeApproxMonthChange", () => {
  it("returns null for empty array", () => {
    expect(computeApproxMonthChange([])).toBeNull();
  });

  it("returns null for single snapshot", () => {
    expect(
      computeApproxMonthChange([{ date: "2026-03-01", value: 100_000 }])
    ).toBeNull();
  });

  it("computes correct absolute and percent change", () => {
    const result = computeApproxMonthChange([
      { date: "2026-02-25", value: 80_000 },
      { date: "2026-03-26", value: 100_000 },
    ]);

    expect(result).not.toBeNull();
    expect(result!.absolute).toBe(20_000);
    expect(result!.percent).toBeCloseTo(25.0, 5);
  });

  it("computes negative change correctly", () => {
    const result = computeApproxMonthChange([
      { date: "2026-02-25", value: 100_000 },
      { date: "2026-03-26", value: 80_000 },
    ]);

    expect(result).not.toBeNull();
    expect(result!.absolute).toBe(-20_000);
    expect(result!.percent).toBeCloseTo(-20.0, 5);
  });

  it("returns 0 percent when baseline value is 0 (no divide-by-zero)", () => {
    const result = computeApproxMonthChange([
      { date: "2026-02-25", value: 0 },
      { date: "2026-03-26", value: 5_000 },
    ]);

    expect(result).not.toBeNull();
    expect(result!.absolute).toBe(5_000);
    expect(result!.percent).toBe(0);
  });

  it("handles unsorted input by sorting internally", () => {
    const sorted = computeApproxMonthChange([
      { date: "2026-02-25", value: 80_000 },
      { date: "2026-03-26", value: 100_000 },
    ]);
    const unsorted = computeApproxMonthChange([
      { date: "2026-03-26", value: 100_000 },
      { date: "2026-02-25", value: 80_000 },
    ]);

    expect(unsorted!.absolute).toBe(sorted!.absolute);
    expect(unsorted!.percent).toBeCloseTo(sorted!.percent, 5);
  });

  it("uses snapshot within 30-day window as baseline, ignores older snapshots", () => {
    // day 0 = "latest" = 2026-03-26 (value: 100k)
    // day -20 = 2026-03-06 (value: 90k) — within 30-day window → should be baseline
    // day -60 = 2026-01-25 (value: 50k) — older than 30 days → should NOT be baseline
    const result = computeApproxMonthChange([
      { date: "2026-01-25", value: 50_000 }, // day -60
      { date: "2026-03-06", value: 90_000 }, // day -20
      { date: "2026-03-26", value: 100_000 }, // day 0 (latest)
    ]);

    expect(result).not.toBeNull();
    // Baseline should be day -20 (90k), not day -60 (50k)
    expect(result!.absolute).toBe(10_000); // 100k - 90k
    expect(result!.percent).toBeCloseTo(11.11, 1);
  });
});
