import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi } from "vitest";
import React from "react";
import { FireInputsForm } from "../fire-inputs-form";
import { fireProjectionReachable } from "./fixtures";
import type { FireProfileResponse } from "@/types/api";

const mutateAsync = vi.fn().mockResolvedValue({});

vi.mock("@/lib/queries/use-fire", () => ({
  useSaveFireProfile: () => ({
    mutateAsync,
    isPending: false,
    error: null,
  }),
}));

describe("FireInputsForm", () => {
  function renderForm(props: {
    profile?: FireProfileResponse | null;
    projection?: typeof fireProjectionReachable;
    projectionLoading?: boolean;
  }) {
    const client = new QueryClient({
      defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
    });
    return render(
      <QueryClientProvider client={client}>
        <FireInputsForm
          profile={props.profile ?? null}
          projection={props.projection}
          projectionLoading={props.projectionLoading}
        />
      </QueryClientProvider>
    );
  }

  it("shows validation when target retirement age is not above current age", async () => {
    const user = userEvent.setup();
    renderForm({ projection: fireProjectionReachable });

    await user.clear(screen.getByLabelText(/Current age/i));
    await user.type(screen.getByLabelText(/Current age/i), "40");
    await user.clear(screen.getByLabelText(/Target retirement age/i));
    await user.type(screen.getByLabelText(/Target retirement age/i), "38");

    await user.click(screen.getByRole("button", { name: /Run simulation/i }));

    expect(
      await screen.findByText(/Target age must be greater than current age/i)
    ).toBeInTheDocument();
    expect(mutateAsync).not.toHaveBeenCalled();
  });

  it("submits normalized payload on valid run", async () => {
    const user = userEvent.setup();
    const profile: FireProfileResponse = {
      id: "p1",
      currentAge: 35,
      annualIncome: 120_000,
      annualExpenses: 55_000,
      targetRetirementAge: 55,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    };
    renderForm({ profile, projection: fireProjectionReachable });

    await user.clear(screen.getByLabelText(/Current age/i));
    await user.type(screen.getByLabelText(/Current age/i), "36");
    await user.click(screen.getByRole("button", { name: /Run simulation/i }));

    expect(mutateAsync).toHaveBeenCalledWith(
      expect.objectContaining({
        currentAge: 36,
        annualIncome: 120_000,
        annualExpenses: 55_000,
        targetRetirementAge: 55,
      })
    );
  });
});
