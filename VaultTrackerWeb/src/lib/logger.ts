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
    context?: Record<string, unknown>
  ): void {
    safeRun(() => {
      if (isProd()) {
        Sentry.captureException(error ?? new Error(message), {
          extra: hasContext(context) ? context : undefined,
        });
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
