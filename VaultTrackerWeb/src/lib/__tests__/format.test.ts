import { format } from "date-fns";
import { describe, expect, it } from "vitest";
import { formatCurrency, formatDate, formatDateTime } from "@/lib/format";

describe("formatCurrency", () => {
  it("formats USD with grouping and two decimals", () => {
    expect(formatCurrency(1234.5)).toBe(
      new Intl.NumberFormat(undefined, {
        style: "currency",
        currency: "USD",
        maximumFractionDigits: 2,
      }).format(1234.5)
    );
  });
});

describe("formatDate", () => {
  it("formats a valid ISO string with MMM d, yyyy", () => {
    const iso = "2024-03-15T12:00:00.000Z";
    expect(formatDate(iso)).toBe(
      format(new Date(iso), "MMM d, yyyy")
    );
  });

  it("returns the input when parsing fails", () => {
    expect(formatDate("not-a-date")).toBe("not-a-date");
  });
});

describe("formatDateTime", () => {
  it("includes a time component (HH:mm)", () => {
    const iso = "2024-06-01T15:30:00.000Z";
    const out = formatDateTime(iso);
    expect(out).toBe(format(new Date(iso), "MMM d, yyyy HH:mm"));
    expect(out).toMatch(/\d{1,2}:\d{2}/);
  });
});
