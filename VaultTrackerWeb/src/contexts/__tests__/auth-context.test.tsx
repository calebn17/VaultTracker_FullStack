import { act, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mockLogger = vi.hoisted(() => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

vi.mock("@/lib/logger", () => ({ logger: mockLogger }));

const mockRouterPush = vi.hoisted(() => vi.fn());
const mockSignOut = vi.hoisted(() => vi.fn().mockResolvedValue(undefined));
const mockSignInWithPopup = vi.hoisted(() => vi.fn().mockResolvedValue(undefined));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: mockRouterPush, replace: vi.fn() }),
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn((_auth: unknown, _cb: (u: unknown) => void) => {
    return () => {};
  }),
  signInWithPopup: mockSignInWithPopup,
  signOut: mockSignOut,
  GoogleAuthProvider: vi.fn(),
}));

vi.mock("@/lib/firebase", () => ({
  isFirebaseConfigured: false,
  getFirebaseApp: vi.fn(),
  getFirebaseAuth: vi.fn(() => ({ currentUser: null })),
  googleProvider: {},
}));

vi.mock("@/lib/auth-debug", () => ({
  DEBUG_AUTH_AVAILABLE: true,
  DEBUG_AUTH_TOKEN: "vaulttracker-debug-user",
}));

import { AuthProvider, useAuth } from "../auth-context";

beforeEach(() => {
  mockLogger.info.mockClear();
  mockLogger.warn.mockClear();
  mockLogger.error.mockClear();
});

afterEach(() => {
  vi.clearAllMocks();
});

function Inspector({ onReady }: { onReady: (ctx: ReturnType<typeof useAuth>) => void }) {
  const ctx = useAuth();
  onReady(ctx);
  return <div data-testid="ready" />;
}

describe("AuthProvider — debug mode", () => {
  it("signInDebug sets mode to debug and creates a stub user", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    act(() => {
      ctx!.signInDebug?.();
    });

    await waitFor(() => {
      expect(ctx!.mode).toBe("debug");
      expect(ctx!.user).not.toBeNull();
      expect(ctx!.user?.uid).toBe("debug-local");
    });
  });

  it("getToken in debug mode returns the debug token", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    act(() => {
      ctx!.signInDebug?.();
    });

    await waitFor(() => expect(ctx!.mode).toBe("debug"));

    await expect(ctx!.getToken()).resolves.toBe("vaulttracker-debug-user");
  });

  it("signOutUser in debug mode resets user and redirects to /login", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    act(() => {
      ctx!.signInDebug?.();
    });

    await waitFor(() => expect(ctx!.mode).toBe("debug"));

    await act(async () => {
      await ctx!.signOutUser();
    });

    expect(ctx!.user).toBeNull();
    expect(mockRouterPush).toHaveBeenCalledWith("/login");
    expect(mockLogger.info).toHaveBeenCalledWith("User signed out");
  });
});

describe("AuthProvider — initial state", () => {
  it("renders children", () => {
    render(
      <AuthProvider>
        <span>child</span>
      </AuthProvider>
    );
    expect(screen.getByText("child")).toBeInTheDocument();
  });
});
