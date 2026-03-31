import { afterEach, describe, expect, it, vi } from "vitest";
import { logger } from "@/lib/logger";

describe("logger", () => {
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
  });

  it("warn does not call console.warn in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    logger.warn("careful", { b: 2 });
    expect(warn).not.toHaveBeenCalled();
  });

  it("warn calls console.warn in non-production", () => {
    vi.stubEnv("NODE_ENV", "development");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    logger.warn("careful", { b: 2 });
    expect(warn).toHaveBeenCalledWith("careful", { b: 2 });
  });

  it("error does not call console.error in production", () => {
    vi.stubEnv("NODE_ENV", "production");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const err = new Error("x");
    logger.error("failed", err, { c: 3 });
    expect(errSpy).not.toHaveBeenCalled();
  });

  it("error calls console.error in non-production with error and context", () => {
    vi.stubEnv("NODE_ENV", "development");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const err = new Error("x");
    logger.error("failed", err, { c: 3 });
    expect(errSpy).toHaveBeenCalledWith("failed", err, { c: 3 });
  });

  it("error calls console.error with message only when no error or context", () => {
    vi.stubEnv("NODE_ENV", "development");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    logger.error("oops");
    expect(errSpy).toHaveBeenCalledWith("oops");
  });
});
