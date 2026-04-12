import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi } from "vitest";
import React from "react";

vi.mock("@/lib/queries/use-fire", () => ({
  useFireProfile: () => ({
    isSuccess: true,
    data: null,
    isError: false,
    isPending: false,
  }),
  useFireProjection: () => ({
    data: undefined,
    isLoading: false,
    isError: false,
    isFetching: false,
  }),
  useSaveFireProfile: () => ({
    mutateAsync: vi.fn().mockResolvedValue({}),
    isPending: false,
    error: null,
  }),
}));

import FirePage from "../page";

function renderPage() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <FirePage />
    </QueryClientProvider>
  );
}

describe("FirePage", () => {
  it("renders a named region and primary heading", () => {
    renderPage();
    expect(screen.getByRole("region", { name: /FIRE calculator/i })).toBeInTheDocument();
    expect(screen.getByRole("heading", { level: 1, name: /FIRE calculator/i })).toBeInTheDocument();
  });
});
