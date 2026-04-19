"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Copy, Users } from "lucide-react";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
import { ApiError } from "@/lib/api-client";
import {
  useCreateHousehold,
  useGenerateInviteCode,
  useHousehold,
  useJoinHousehold,
  useLeaveHousehold,
} from "@/lib/queries/use-household";

const MAX_MEMBERS_V1 = 2;

function errorMessage(e: unknown): string {
  if (e instanceof ApiError) return e.message;
  if (e instanceof Error) return e.message;
  return "Something went wrong";
}

export function HouseholdSettingsCard() {
  const { data: household, isPending, isError, error, refetch } = useHousehold();
  const create = useCreateHousehold();
  const join = useJoinHousehold();
  const generate = useGenerateInviteCode();
  const leave = useLeaveHousehold();

  const [joinCode, setJoinCode] = useState("");
  const [lastInvite, setLastInvite] = useState<{ code: string; expiresAt: string } | null>(null);
  const [leaveOpen, setLeaveOpen] = useState(false);

  const inHousehold = household != null;
  const memberCount = household?.members.length ?? 0;
  const canInvite = inHousehold && memberCount < MAX_MEMBERS_V1;

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="size-5" aria-hidden />
            Household
          </CardTitle>
          <CardDescription>
            Share household dashboard and FIRE inputs with one partner. Accounts and transactions
            stay personal.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4 text-sm">
          {isPending ? (
            <p className="text-muted-foreground" data-testid="household-loading">
              Loading household…
            </p>
          ) : isError ? (
            <div className="space-y-2">
              <p className="text-destructive" role="alert">
                {error instanceof Error ? error.message : "Could not load household"}
              </p>
              <Button type="button" variant="outline" size="sm" onClick={() => void refetch()}>
                Retry
              </Button>
            </div>
          ) : !inHousehold ? (
            <div className="space-y-4" data-testid="household-not-in">
              <div className="space-y-2">
                <Button
                  type="button"
                  className="w-full sm:w-auto"
                  disabled={create.isPending}
                  onClick={() =>
                    create.mutate(undefined, {
                      onSuccess: () => toast.success("Household created"),
                      onError: (e) => toast.error(errorMessage(e)),
                    })
                  }
                >
                  {create.isPending ? "Creating…" : "Create household"}
                </Button>
              </div>
              <div className="relative">
                <div className="absolute inset-0 flex items-center">
                  <span className="w-full border-t" />
                </div>
                <div className="relative flex justify-center text-xs uppercase">
                  <span className="bg-card px-2 text-muted-foreground">Or join</span>
                </div>
              </div>
              <div className="grid gap-2">
                <Label htmlFor="join-code">Invite code</Label>
                <div className="flex flex-col gap-2 sm:flex-row">
                  <Input
                    id="join-code"
                    name="joinCode"
                    placeholder="Enter code"
                    value={joinCode}
                    onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                    autoComplete="off"
                    className="font-mono uppercase sm:max-w-xs"
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={join.isPending || joinCode.trim().length === 0}
                    onClick={() =>
                      join.mutate(
                        { code: joinCode.trim() },
                        {
                          onSuccess: () => {
                            toast.success("Joined household");
                            setJoinCode("");
                          },
                          onError: (e) => toast.error(errorMessage(e)),
                        }
                      )
                    }
                  >
                    {join.isPending ? "Joining…" : "Join household"}
                  </Button>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-4" data-testid="household-in">
              <div>
                <p className="mb-2 font-medium">Members ({memberCount})</p>
                <ul className="list-inside list-disc space-y-1 text-muted-foreground">
                  {household.members.map((m) => (
                    <li key={m.userId} data-testid="household-member">
                      {m.email ?? m.userId}
                    </li>
                  ))}
                </ul>
              </div>

              {canInvite ? (
                <div className="space-y-2">
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={generate.isPending}
                    onClick={() =>
                      generate.mutate(undefined, {
                        onSuccess: (res) => {
                          setLastInvite({
                            code: res.code,
                            expiresAt: res.expiresAt,
                          });
                          toast.success("Invite code generated");
                        },
                        onError: (e) => toast.error(errorMessage(e)),
                      })
                    }
                  >
                    {generate.isPending ? "Generating…" : "Generate invite code"}
                  </Button>
                  {lastInvite ? (
                    <div
                      className="rounded-md border bg-muted/40 p-3 font-mono text-xs"
                      data-testid="household-invite-preview"
                    >
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-base font-semibold tracking-wider">
                          {lastInvite.code}
                        </span>
                        <Button
                          type="button"
                          size="sm"
                          variant="outline"
                          className="h-8"
                          onClick={async () => {
                            try {
                              await navigator.clipboard.writeText(lastInvite.code);
                              toast.success("Code copied");
                            } catch {
                              toast.error("Could not copy");
                            }
                          }}
                        >
                          <Copy className="mr-1 size-3.5" />
                          Copy
                        </Button>
                      </div>
                      <p className="mt-2 text-muted-foreground">
                        Expires {format(new Date(lastInvite.expiresAt), "PPp")}
                      </p>
                    </div>
                  ) : null}
                </div>
              ) : (
                <p className="text-muted-foreground">Your household is full (2 members).</p>
              )}

              <Button
                type="button"
                variant="outline"
                className="border-destructive/50 text-destructive hover:bg-destructive/10"
                disabled={leave.isPending}
                onClick={() => setLeaveOpen(true)}
              >
                Leave household
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      <AlertDialog open={leaveOpen} onOpenChange={setLeaveOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Leave household?</AlertDialogTitle>
            <AlertDialogDescription>
              You will switch back to a personal-only dashboard and FIRE profile. If you are the
              last member, the household is removed.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <Button
              type="button"
              variant="destructive"
              disabled={leave.isPending}
              onClick={() =>
                leave.mutate(undefined, {
                  onSuccess: () => {
                    toast.success("Left household");
                    setLeaveOpen(false);
                    setLastInvite(null);
                  },
                  onError: (e) => toast.error(errorMessage(e)),
                })
              }
            >
              {leave.isPending ? "Leaving…" : "Leave household"}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
