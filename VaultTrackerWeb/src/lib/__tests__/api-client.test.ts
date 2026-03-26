import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiClient, ApiError } from "@/lib/api-client";

function jsonResponse(data: unknown, status = 200, statusText = "OK") {
  return new Response(JSON.stringify(data), {
    status,
    statusText,
    headers: { "Content-Type": "application/json" },
  });
}

describe("ApiClient", () => {
  const baseUrl = "http://localhost:8000";
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("resolves with parsed JSON on 200", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse({ hello: "world" }));
    const getToken = vi.fn().mockResolvedValue("tok");
    const onUnauthorized = vi.fn();
    const client = new ApiClient(baseUrl, getToken, onUnauthorized);

    await expect(client.get("/api/v1/foo")).resolves.toEqual({
      hello: "world",
    });
    expect(getToken).toHaveBeenCalledWith(false);
    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:8000/api/v1/foo",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer tok",
        }),
      })
    );
  });

  it("resolves with undefined on 204", async () => {
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));
    const client = new ApiClient(baseUrl, vi.fn().mockResolvedValue("t"), vi.fn());

    await expect(client.get("/x")).resolves.toBeUndefined();
  });

  it("throws ApiError with status on 4xx/5xx", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({ detail: "bad" }, 404, "Not Found")
    );
    const client = new ApiClient(baseUrl, vi.fn().mockResolvedValue("t"), vi.fn());

    await expect(client.get("/missing")).rejects.toMatchObject({
      name: "ApiError",
      status: 404,
    });
  });

  it("on 401, retries once with force-refreshed token and returns body", async () => {
    const getToken = vi
      .fn()
      .mockResolvedValueOnce("first")
      .mockResolvedValueOnce("second");
    fetchMock
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(jsonResponse({ ok: true }));

    const client = new ApiClient(baseUrl, getToken, vi.fn());
    await expect(client.get("/r")).resolves.toEqual({ ok: true });

    expect(getToken).toHaveBeenCalledTimes(2);
    expect(getToken).toHaveBeenNthCalledWith(1, false);
    expect(getToken).toHaveBeenNthCalledWith(2, true);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(fetchMock.mock.calls[1][1]).toMatchObject({
      headers: expect.objectContaining({
        Authorization: "Bearer second",
      }),
    });
  });

  it("on 401 then 401, calls onUnauthorized and throws ApiError(401)", async () => {
    const getToken = vi.fn().mockResolvedValue("t");
    const onUnauthorized = vi.fn();
    fetchMock
      .mockResolvedValueOnce(new Response(null, { status: 401 }))
      .mockResolvedValueOnce(new Response(null, { status: 401 }));

    const client = new ApiClient(baseUrl, getToken, onUnauthorized);

    await expect(client.get("/x")).rejects.toMatchObject({
      name: "ApiError",
      status: 401,
    });
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });
});

describe("ApiError.fromResponse", () => {
  it("uses string detail from JSON body", async () => {
    const res = jsonResponse({ detail: "msg" }, 400);
    const err = await ApiError.fromResponse(res);
    expect(err.message).toBe("msg");
    expect(err.status).toBe(400);
  });

  it("falls back to statusText when body is not JSON with detail", async () => {
    const res = new Response("plain", {
      status: 502,
      statusText: "Bad Gateway",
      headers: { "Content-Type": "text/plain" },
    });
    const err = await ApiError.fromResponse(res);
    expect(err.message).toBe("Bad Gateway");
    expect(err.status).toBe(502);
  });
});
