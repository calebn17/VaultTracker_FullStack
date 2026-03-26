import { render, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn((_auth: unknown, _cb: (u: unknown) => void) => {
    return () => {};
  }),
  signInWithPopup: vi.fn(),
  signOut: vi.fn(),
  GoogleAuthProvider: vi.fn(),
}));

vi.mock("@/lib/firebase", () => ({
  isFirebaseConfigured: false,
  getFirebaseApp: vi.fn(),
  getFirebaseAuth: vi.fn(() => ({ currentUser: null })),
  googleProvider: {},
}));

vi.mock("@/lib/auth-debug", () => ({
  DEBUG_AUTH_AVAILABLE: false,
  DEBUG_AUTH_TOKEN: "",
}));

import { AuthProvider, useAuth } from "../auth-context";

describe("AuthProvider — production (no debug auth)", () => {
  it("exposes signInDebug as undefined in context value", async () => {
    let ctx: ReturnType<typeof useAuth> | null = null;
    function Probe() {
      ctx = useAuth();
      return null;
    }

    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>
    );

    await waitFor(() => expect(ctx).not.toBeNull());
    expect(ctx!.signInDebug).toBeUndefined();
  });
});
