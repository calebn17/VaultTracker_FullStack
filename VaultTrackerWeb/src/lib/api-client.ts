import { logger } from "@/lib/logger";

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public body?: unknown
  ) {
    super(message);
    this.name = "ApiError";
  }

  static async fromResponse(res: Response): Promise<ApiError> {
    const raw = await res.text();
    let body: unknown;
    try {
      body = raw ? JSON.parse(raw) : undefined;
    } catch {
      body = raw;
    }
    const msg =
      typeof body === "object" &&
      body !== null &&
      "detail" in body &&
      typeof (body as { detail: unknown }).detail === "string"
        ? String((body as { detail: string }).detail)
        : res.statusText;
    return new ApiError(msg || "Request failed", res.status, body);
  }
}

export class ApiClient {
  constructor(
    private baseUrl: string,
    private getToken: (forceRefresh?: boolean) => Promise<string>,
    private onUnauthorized: () => void
  ) {}

  async request<T>(endpoint: string, options?: RequestInit): Promise<T> {
    const start = Date.now();
    const method = options?.method ?? "GET";
    const token = await this.getToken(false);
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        ...options?.headers,
      },
    });

    if (response.status === 401) {
      logger.warn("401 — retrying with refreshed token", { endpoint });
      const freshToken = await this.getToken(true);
      const retry = await fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers: {
          Authorization: `Bearer ${freshToken}`,
          "Content-Type": "application/json",
          ...options?.headers,
        },
      });
      if (retry.status === 401) {
        this.onUnauthorized();
        const err = new ApiError("unauthorized", 401);
        logger.error("API error", err, { status: 401, endpoint });
        throw err;
      }
      if (retry.status === 204) {
        logger.info("API request", {
          method,
          endpoint,
          durationMs: Date.now() - start,
        });
        return undefined as T;
      }
      if (!retry.ok) {
        const err = await ApiError.fromResponse(retry);
        logger.error("API error", err, { status: err.status, endpoint });
        throw err;
      }
      logger.info("API request", {
        method,
        endpoint,
        durationMs: Date.now() - start,
      });
      return retry.json() as Promise<T>;
    }

    if (response.status === 204) {
      logger.info("API request", {
        method,
        endpoint,
        durationMs: Date.now() - start,
      });
      return undefined as T;
    }

    if (!response.ok) {
      const err = await ApiError.fromResponse(response);
      logger.error("API error", err, { status: err.status, endpoint });
      throw err;
    }

    logger.info("API request", {
      method,
      endpoint,
      durationMs: Date.now() - start,
    });
    return response.json() as Promise<T>;
  }

  get<T>(endpoint: string) {
    return this.request<T>(endpoint);
  }

  post<T>(endpoint: string, body: unknown) {
    return this.request<T>(endpoint, {
      method: "POST",
      body: JSON.stringify(body),
    });
  }

  put<T>(endpoint: string, body: unknown) {
    return this.request<T>(endpoint, {
      method: "PUT",
      body: JSON.stringify(body),
    });
  }

  delete(endpoint: string) {
    return this.request<void>(endpoint, { method: "DELETE" });
  }
}
