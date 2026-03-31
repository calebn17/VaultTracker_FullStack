import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const sentryMocks = vi.hoisted(() => ({
  captureMessage: vi.fn(),
  captureException: vi.fn(),
}));

vi.mock("@sentry/nextjs", () => ({
  captureMessage: sentryMocks.captureMessage,
  captureException: sentryMocks.captureException,
}));

import { logger } from "@/lib/logger";

describe("logger", () => {
  beforeEach(() => {
    sentryMocks.captureMessage.mockClear();
    sentryMocks.captureException.mockClear();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
  });

  it("info does not call console.log in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    logger.info("hello", { a: 1 });
    expect(log).not.toHaveBeenCalled();
  });

  it("info calls console.log in non-production", () => {
    vi.stubEnv("NODE_ENV", "development");
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    logger.info("hello", { a: 1 });
    expect(log).toHaveBeenCalledWith("hello", { a: 1 });
    expect(sentryMocks.captureMessage).not.toHaveBeenCalled();
  });

  it("warn calls Sentry.captureMessage in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    logger.warn("careful", { b: 2 });
    expect(warn).not.toHaveBeenCalled();
    expect(sentryMocks.captureMessage).toHaveBeenCalledWith("careful", {
      level: "warning",
      extra: { b: 2 },
    });
  });

  it("warn calls console.warn in non-production", () => {
    vi.stubEnv("NODE_ENV", "development");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    logger.warn("careful", { b: 2 });
    expect(warn).toHaveBeenCalledWith("careful", { b: 2 });
    expect(sentryMocks.captureMessage).not.toHaveBeenCalled();
  });

  it("error calls Sentry.captureException in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const err = new Error("x");
    logger.error("failed", err, { c: 3 });
    expect(errSpy).not.toHaveBeenCalled();
    expect(sentryMocks.captureException).toHaveBeenCalledWith(err, {
      extra: { c: 3 },
    });
  });

  it("error uses synthetic Error when production and no error passed", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.spyOn(console, "error").mockImplementation(() => {});
    logger.error("only message", undefined, { d: 4 });
    expect(sentryMocks.captureException).toHaveBeenCalledWith(
      expect.objectContaining({ message: "only message" }),
      { extra: { d: 4 } }
    );
  });

  it("error calls console.error in non-production with error and context", () => {
    vi.stubEnv("NODE_ENV", "development");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const err = new Error("x");
    logger.error("failed", err, { c: 3 });
    expect(errSpy).toHaveBeenCalledWith("failed", err, { c: 3 });
    expect(sentryMocks.captureException).not.toHaveBeenCalled();
  });

  it("error calls console.error with message only when no error or context", () => {
    vi.stubEnv("NODE_ENV", "development");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    logger.error("oops");
    expect(errSpy).toHaveBeenCalledWith("oops");
  });
});
