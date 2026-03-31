import { act, render, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mockLogger = vi.hoisted(() => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

vi.mock("@/lib/logger", () => ({ logger: mockLogger }));

const mockSignInWithPopup = vi.hoisted(() =>
  vi.fn().mockResolvedValue({ user: { uid: "firebase-test-uid" } })
);
const mockGetIdToken = vi.hoisted(() => vi.fn().mockResolvedValue("id-token"));
const mockGetFirebaseAuth = vi.hoisted(() =>
  vi.fn().mockReturnValue({
    currentUser: {
      uid: "current-uid",
      getIdToken: mockGetIdToken,
    },
  })
);

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn(
    (_auth: unknown, _cb: (u: unknown) => void) => () => {}
  ),
  signInWithPopup: mockSignInWithPopup,
  signOut: vi.fn().mockResolvedValue(undefined),
  GoogleAuthProvider: vi.fn(),
}));

vi.mock("@/lib/firebase", () => ({
  isFirebaseConfigured: true,
  getFirebaseApp: vi.fn(),
  getFirebaseAuth: mockGetFirebaseAuth,
  googleProvider: {},
}));

vi.mock("@/lib/auth-debug", () => ({
  DEBUG_AUTH_AVAILABLE: false,
  DEBUG_AUTH_TOKEN: "",
}));

import { AuthProvider, useAuth } from "../auth-context";

function Inspector({
  onReady,
}: {
  onReady: (ctx: ReturnType<typeof useAuth>) => void;
}) {
  const ctx = useAuth();
  onReady(ctx);
  return <div data-testid="ready" />;
}

describe("AuthProvider — logging (Firebase configured)", () => {
  beforeEach(() => {
    mockLogger.info.mockClear();
    mockLogger.warn.mockClear();
    mockLogger.error.mockClear();
    mockSignInWithPopup.mockResolvedValue({
      user: { uid: "firebase-test-uid" },
    });
    mockGetIdToken.mockResolvedValue("id-token");
    mockGetFirebaseAuth.mockReset();
    mockGetFirebaseAuth.mockReturnValue({
      currentUser: {
        uid: "current-uid",
        getIdToken: mockGetIdToken,
      },
    });
  });

  it("logs info when Google sign-in succeeds", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    await act(async () => {
      await ctx!.signInWithGoogle();
    });

    expect(mockLogger.info).toHaveBeenCalledWith("User signed in", {
      uid: "firebase-test-uid",
    });
  });

  it("logs error when Google sign-in fails", async () => {
    mockSignInWithPopup.mockRejectedValueOnce(new Error("popup closed"));
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    await act(async () => {
      await expect(ctx!.signInWithGoogle()).rejects.toThrow("popup closed");
    });

    expect(mockLogger.error).toHaveBeenCalledWith(
      "Sign-in failed",
      expect.any(Error)
    );
  });

  it("does not log force-refresh warn when not signed in", async () => {
    mockGetFirebaseAuth.mockReturnValue({ currentUser: null });
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    await act(async () => {
      await expect(ctx!.getToken(true)).rejects.toThrow("Not signed in");
    });

    expect(mockLogger.warn).not.toHaveBeenCalled();
  });

  it("logs warn when getToken forces refresh", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    await act(async () => {
      await ctx!.getToken(true);
    });

    expect(mockLogger.warn).toHaveBeenCalledWith(
      "Force-refreshing token after 401"
    );
    expect(mockGetIdToken).toHaveBeenCalledWith(true);
  });

  it("logs error when getIdToken rejects", async () => {
    mockGetIdToken.mockRejectedValueOnce(new Error("token failed"));
    let ctx: ReturnType<typeof useAuth> | null = null;
    render(
      <AuthProvider>
        <Inspector onReady={(c) => (ctx = c)} />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());

    await act(async () => {
      await expect(ctx!.getToken(false)).rejects.toThrow("token failed");
    });

    expect(mockLogger.error).toHaveBeenCalledWith(
      "Token refresh failed",
      expect.any(Error)
    );
  });
});
