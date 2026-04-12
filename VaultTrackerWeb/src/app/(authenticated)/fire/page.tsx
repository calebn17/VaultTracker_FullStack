"use client";

/**
 * FIRE calculator (Financial Independence, Retire Early).
 * Full inputs, projection chart, and hooks are added in follow-up slices.
 */
export default function FirePage() {
  return (
    <section aria-labelledby="fire-title" className="space-y-2">
      <h1 id="fire-title" className="font-serif text-2xl tracking-tight text-foreground">
        FIRE calculator
      </h1>
      <p className="text-muted-foreground text-sm">
        Run simulations from your portfolio and saved inputs — full UI coming next.
      </p>
    </section>
  );
}
