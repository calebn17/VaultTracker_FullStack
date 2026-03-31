import * as Sentry from "@sentry/nextjs";

function isProd(): boolean {
  return process.env.NODE_ENV === "production";
}

function safeRun(fn: () => void): void {
  try {
    fn();
  } catch {
    // Logger must never throw
  }
}

function hasContext(context?: Record<string, unknown>): boolean {
  return context !== undefined && Object.keys(context).length > 0;
}

/** Optional Sentry scope enrichment; only applied in production inside this module. */
export type LoggerErrorSentryScope = {
  tags?: Record<string, string>;
  contexts?: Record<string, Record<string, unknown>>;
};

/**
 * Central logging facade. Sentry is only imported/used from this module.
 * Do not log tokens, emails, or other PII in context.
 */
export const logger = {
  info(message: string, context?: Record<string, unknown>): void {
    if (isProd()) return;
    safeRun(() => {
      if (hasContext(context)) {
        console.log(message, context);
      } else {
        console.log(message);
      }
    });
  },

  warn(message: string, context?: Record<string, unknown>): void {
    safeRun(() => {
      if (isProd()) {
        Sentry.captureMessage(message, {
          level: "warning",
          extra: hasContext(context) ? context : undefined,
        });
        return;
      }
      if (hasContext(context)) {
        console.warn(message, context);
      } else {
        console.warn(message);
      }
    });
  },

  error(
    message: string,
    error?: unknown,
    context?: Record<string, unknown>,
    sentryScope?: LoggerErrorSentryScope
  ): void {
    safeRun(() => {
      if (isProd()) {
        const extra = hasContext(context) ? context : undefined;
        const exception = error ?? new Error(message);
        const capture = () => {
          Sentry.captureException(exception, { extra });
        };
        const hasSentryScope =
          (sentryScope?.tags !== undefined &&
            Object.keys(sentryScope.tags).length > 0) ||
          (sentryScope?.contexts !== undefined &&
            Object.keys(sentryScope.contexts).length > 0);
        if (hasSentryScope) {
          Sentry.withScope((scope) => {
            for (const [k, v] of Object.entries(sentryScope?.tags ?? {})) {
              scope.setTag(k, v);
            }
            for (const [k, v] of Object.entries(sentryScope?.contexts ?? {})) {
              scope.setContext(k, v);
            }
            capture();
          });
        } else {
          capture();
        }
        return;
      }
      if (error !== undefined) {
        if (hasContext(context)) {
          console.error(message, error, context);
        } else {
          console.error(message, error);
        }
      } else if (hasContext(context)) {
        console.error(message, context);
      } else {
        console.error(message);
      }
    });
  },
};
