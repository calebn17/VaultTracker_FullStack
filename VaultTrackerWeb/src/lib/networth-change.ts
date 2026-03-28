/**
 * Approximate trailing-30-day change from snapshot series (latest vs oldest point
 * in the window ending at the latest snapshot).
 */
export function computeApproxMonthChange(
  snapshots: Array<{ date: string; value: number }>
): { absolute: number; percent: number } | null {
  if (snapshots.length < 2) return null;
  const sorted = [...snapshots].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
  );
  const latest = sorted[sorted.length - 1];
  const cutoff = new Date(latest.date);
  cutoff.setDate(cutoff.getDate() - 30);
  const t = cutoff.getTime();
  let baseline = sorted[0];
  for (const s of sorted) {
    if (new Date(s.date).getTime() <= t) baseline = s;
    else break;
  }
  const absolute = latest.value - baseline.value;
  const percent = baseline.value !== 0 ? (absolute / baseline.value) * 100 : 0;
  return { absolute, percent };
}
