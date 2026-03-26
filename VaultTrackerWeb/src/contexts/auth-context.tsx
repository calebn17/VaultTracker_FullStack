"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";
import {
  onAuthStateChanged,
  signInWithPopup,
  signOut,
  type User,
} from "firebase/auth";
import { DEBUG_AUTH_AVAILABLE, DEBUG_AUTH_TOKEN } from "@/lib/auth-debug";
import { getFirebaseAuth, googleProvider, isFirebaseConfigured } from "@/lib/firebase";

type AuthMode = "firebase" | "debug";

type AuthContextValue = {
  user: User | null;
  loading: boolean;
  mode: AuthMode;
  signInWithGoogle: () => Promise<void>;
  signInDebug?: () => void;
  signOutUser: () => Promise<void>;
  getToken: (forceRefresh?: boolean) => Promise<string>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<AuthMode>("firebase");

  useEffect(() => {
    if (!isFirebaseConfigured) {
      setLoading(false);
      return;
    }
    const auth = getFirebaseAuth();
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u);
      setMode("firebase");
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const signInWithGoogle = useCallback(async () => {
    const auth = getFirebaseAuth();
    await signInWithPopup(auth, googleProvider);
  }, []);

  const signInDebug = useMemo(() => {
    if (!DEBUG_AUTH_AVAILABLE) return undefined;
    return () => {
      setMode("debug");
      setUser({ uid: "debug-local" } as User);
      setLoading(false);
    };
  }, []);

  const signOutUser = useCallback(async () => {
    if (mode === "debug") {
      setUser(null);
      setMode("firebase");
      router.push("/login");
      return;
    }
    if (isFirebaseConfigured) {
      await signOut(getFirebaseAuth());
    }
    router.push("/login");
  }, [mode, router]);

  const getToken = useCallback(
    async (forceRefresh = false) => {
      if (mode === "debug") {
        if (!DEBUG_AUTH_TOKEN) {
          throw new Error("Debug authentication is not available.");
        }
        return DEBUG_AUTH_TOKEN;
      }
      const auth = getFirebaseAuth();
      const u = auth.currentUser;
      if (!u) {
        throw new Error("Not signed in");
      }
      return u.getIdToken(forceRefresh);
    },
    [mode]
  );

  const value = useMemo(() => {
    const base = {
      user,
      loading,
      mode,
      signInWithGoogle,
      signOutUser,
      getToken,
    };
    return signInDebug === undefined
      ? base
      : { ...base, signInDebug };
  }, [
    user,
    loading,
    mode,
    signInWithGoogle,
    signInDebug,
    signOutUser,
    getToken,
  ]);

  return (
    <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return ctx;
}

export function useOptionalAuth() {
  return useContext(AuthContext);
}
