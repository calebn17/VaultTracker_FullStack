import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export function StatCard({
  title,
  value,
  loading,
  variant = "default",
}: {
  title: string;
  value: string;
  loading?: boolean;
  variant?: "default" | "hero" | "compact";
}) {
  if (variant === "hero") {
    return (
      <div>
        <p className="text-muted-foreground mb-2 text-[11px] uppercase tracking-[0.12em]">
          {title}
        </p>
        {loading ? (
          <Skeleton className="h-14 w-64 max-w-full md:h-[72px]" />
        ) : (
          <p className="font-serif text-5xl leading-none tracking-tighter text-foreground tabular-nums md:text-[64px]">
            {value}
          </p>
        )}
      </div>
    );
  }

  if (variant === "compact") {
    return (
      <Card size="sm" className="gap-2 py-3">
        <CardHeader className="pb-0">
          <CardTitle className="text-muted-foreground text-xs font-medium">{title}</CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          {loading ? (
            <Skeleton className="h-6 w-24" />
          ) : (
            <p className="text-lg font-semibold tabular-nums">{value}</p>
          )}
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-muted-foreground text-sm font-medium">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {loading ? (
          <Skeleton className="h-8 w-28" />
        ) : (
          <p className="text-2xl font-semibold tabular-nums">{value}</p>
        )}
      </CardContent>
    </Card>
  );
}
