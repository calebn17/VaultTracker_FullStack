import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
      <div className="space-y-1">
        <p className="text-muted-foreground text-sm font-medium">{title}</p>
        {loading ? (
          <Skeleton className="h-12 w-56 max-w-full md:h-14" />
        ) : (
          <p className="text-4xl font-semibold tracking-tight tabular-nums md:text-5xl">
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
          <CardTitle className="text-muted-foreground text-xs font-medium">
            {title}
          </CardTitle>
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
        <CardTitle className="text-muted-foreground text-sm font-medium">
          {title}
        </CardTitle>
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
