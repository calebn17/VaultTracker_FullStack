"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useAuth } from "@/contexts/auth-context";
import { useDeleteUserData } from "@/lib/queries/use-user";

export default function ProfilePage() {
  const { user, signOutUser, mode } = useAuth();
  const { theme, setTheme } = useTheme();
  const del = useDeleteUserData();
  const [dangerOpen, setDangerOpen] = useState(false);
  const [confirmText, setConfirmText] = useState("");

  return (
    <div className="mx-auto max-w-lg space-y-8">
      <h1 className="text-2xl font-semibold tracking-tight">Profile</h1>

      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
          <CardDescription>Signed in with Firebase</CardDescription>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {mode === "debug" ? (
            <p className="text-muted-foreground">Local debug API session</p>
          ) : (
            <>
              <p>
                <span className="text-muted-foreground">Name: </span>
                {user?.displayName ?? "—"}
              </p>
              <p>
                <span className="text-muted-foreground">Email: </span>
                {user?.email ?? "—"}
              </p>
            </>
          )}
          <Button
            type="button"
            variant="outline"
            className="mt-4"
            onClick={() => signOutUser()}
          >
            Sign out
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Appearance</CardTitle>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="outline"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
          >
            {theme === "dark" ? (
              <Sun className="mr-2 size-4" />
            ) : (
              <Moon className="mr-2 size-4" />
            )}
            Toggle theme
          </Button>
        </CardContent>
      </Card>

      <Card className="border-destructive/50">
        <CardHeader>
          <CardTitle className="text-destructive">Danger zone</CardTitle>
          <CardDescription>
            Deletes all accounts, assets, transactions, and net worth snapshots.
            Your Firebase login is kept.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            type="button"
            variant="destructive"
            onClick={() => {
              setConfirmText("");
              setDangerOpen(true);
            }}
          >
            Delete all financial data
          </Button>
        </CardContent>
      </Card>

      <AlertDialog open={dangerOpen} onOpenChange={setDangerOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete all financial data?</AlertDialogTitle>
            <AlertDialogDescription>
              Type <strong>DELETE</strong> to confirm. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div className="grid gap-2 py-2">
            <Label htmlFor="confirm">Confirmation</Label>
            <Input
              id="confirm"
              value={confirmText}
              onChange={(e) => setConfirmText(e.target.value)}
              placeholder="DELETE"
              autoComplete="off"
            />
          </div>
          <AlertDialogFooter>
            <AlertDialogCancel onClick={() => setConfirmText("")}>
              Cancel
            </AlertDialogCancel>
            <Button
              type="button"
              variant="destructive"
              disabled={confirmText !== "DELETE" || del.isPending}
              onClick={() => {
                del.mutate(undefined, {
                  onSuccess: async () => {
                    toast.success("All financial data removed");
                    setDangerOpen(false);
                    setConfirmText("");
                    await signOutUser();
                  },
                  onError: (e) =>
                    toast.error(
                      e instanceof Error ? e.message : "Delete failed"
                    ),
                });
              }}
            >
              {del.isPending ? "Deleting…" : "Confirm delete"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
