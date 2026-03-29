/**
 * Approximate trailing-30-day change: latest value minus a baseline inside the
 * trailing window. Baseline is the oldest snapshot strictly after (latest − 30d)
 * and strictly before latest; if none exist, falls back to the newest snapshot
 * on or before (latest − 30d) (older history).
 */
export function computeApproxMonthChange(
  snapshots: Array<{ date: string; value: number }>
): { absolute: number; percent: number } | null {
  if (snapshots.length < 2) return null;
  const sorted = [...snapshots].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
  );
  const latest = sorted[sorted.length - 1];
  const latestTime = new Date(latest.date).getTime();
  const cutoff = new Date(latest.date);
  cutoff.setUTCDate(cutoff.getUTCDate() - 30);
  const cutoffTime = cutoff.getTime();

  const inTrailingWindow = sorted.filter((s) => {
    const ts = new Date(s.date).getTime();
    return ts > cutoffTime && ts < latestTime;
  });

  let baseline: (typeof sorted)[number];
  if (inTrailingWindow.length > 0) {
    baseline = inTrailingWindow[0];
  } else {
    baseline = sorted[0];
    for (const s of sorted) {
      if (new Date(s.date).getTime() <= cutoffTime) baseline = s;
      else break;
    }
  }

  const absolute = latest.value - baseline.value;
  const percent = baseline.value !== 0 ? (absolute / baseline.value) * 100 : 0;
  return { absolute, percent };
}
