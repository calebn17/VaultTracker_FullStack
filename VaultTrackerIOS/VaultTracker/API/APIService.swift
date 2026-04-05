//
//  APIService.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation

/// Singleton that wraps URLSession and implements `APIServiceProtocol` for all
/// backend API operations. Every outbound request is authenticated via
/// `AuthTokenProvider`; a 401 triggers a token force-refresh and a single retry
/// before the caller receives an error.
///
/// Uses URLSession directly rather than the legacy `NetworkService` because
/// request bodies must be encoded from typed `Codable` structs, which
/// `NetworkService`'s `[String: String]` body parameter cannot support.
///
/// All thrown errors are typed as `APIError` (see APIError.swift).
final class APIService: APIServiceProtocol {

    // MARK: - Singleton

    static let shared = APIService()

    // MARK: - Private Properties

    private let session: URLSession
    private let log: any VTLogging
    private let tokenProvider: AuthTokenProvider
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Init

    /// - Parameters:
    ///   - session: Injected for unit tests (`URLProtocol`); production uses `shared`.
    ///   - log: Injected for tests (`VTLoggingSpy`); production uses ``VTLogLive``.
    ///   - tokenProvider: Injected for unit tests; production uses `AuthTokenProvider.shared`.
    private init(session: URLSession = .shared, log: any VTLogging = VTLogLive(), tokenProvider: AuthTokenProvider = .shared) {
        self.session = session
        self.log = log
        self.tokenProvider = tokenProvider

        self.decoder = JSONDecoder()
        // Custom date strategy to handle the two formats the backend can return:
        //   1. ISO 8601 with timezone ("2026-03-17T10:30:00+00:00" or "...Z") — preferred.
        //   2. Naive datetime without timezone (legacy rows stored before timezone
        //      support was added); treated as UTC to avoid silent mis-parsing.
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            // Try with timezone (e.g. "2026-03-17T10:30:00+00:00" or "...Z")
            let withTZ = ISO8601DateFormatter()
            withTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withTZ.date(from: raw) { return date }

            withTZ.formatOptions = [.withInternetDateTime]
            if let date = withTZ.date(from: raw) { return date }

            // Fallback: naive datetime from older rows — assume UTC
            let noTZ = ISO8601DateFormatter()
            noTZ.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            noTZ.timeZone = TimeZone(abbreviation: "UTC")
            if let date = noTZ.date(from: raw) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(raw)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

#if DEBUG
    /// Builds an `APIService` with a custom session/logger for unit tests (`URLProtocol`, ``VTLoggingSpy``). App code should use ``shared``.
    static func test_make(session: URLSession = .shared, log: any VTLogging = VTLogLive(), tokenProvider: AuthTokenProvider = .shared) -> APIService {
        APIService(session: session, log: log, tokenProvider: tokenProvider)
    }
#endif

    // MARK: - Dashboard

    func fetchDashboard() async throws -> APIDashboardResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.dashboard)
        return try await perform(request)
    }

    func fetchAnalytics() async throws -> APIAnalyticsResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.analytics)
        return try await perform(request)
    }

    func refreshPrices() async throws -> APIPriceRefreshResult {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.priceRefresh, method: "POST")
        return try await perform(request)
    }

    // MARK: - Accounts

    func fetchAccounts() async throws -> [APIAccountResponse] {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.accounts)
        return try await perform(request)
    }

    func createAccount(_ body: APIAccountCreateRequest) async throws -> APIAccountResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.accounts, method: "POST", body: body)
        return try await perform(request)
    }

    func updateAccount(id: String, _ body: APIAccountUpdateRequest) async throws -> APIAccountResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.account(id: id), method: "PUT", body: body)
        return try await perform(request)
    }

    func deleteAccount(id: String) async throws {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.account(id: id), method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Assets

    func fetchAssets() async throws -> [APIAssetResponse] {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.assets)
        return try await perform(request)
    }

    func createAsset(_ body: APIAssetCreateRequest) async throws -> APIAssetResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.assets, method: "POST", body: body)
        return try await perform(request)
    }

    // MARK: - Transactions

    func fetchTransactions() async throws -> [APIEnrichedTransactionResponse] {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.transactions)
        return try await perform(request)
    }

    func createSmartTransaction(_ body: APISmartTransactionCreateRequest) async throws -> APITransactionResponse {
        let request = try await makeRequest(
            endpoint: APIConfiguration.Endpoints.smartTransaction,
            method: "POST",
            body: body
        )
        return try await perform(request)
    }

    func updateTransaction(id: String, _ body: APITransactionUpdateRequest) async throws -> APITransactionResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.transaction(id: id), method: "PUT", body: body)
        return try await perform(request)
    }

    func deleteTransaction(id: String) async throws {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.transaction(id: id), method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - User Data

    func clearAllData() async throws {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.clearUserData, method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Net Worth History

    func fetchNetWorthHistory(period: APINetWorthPeriod? = nil) async throws -> APINetWorthHistoryResponse {
        var queryItems: [URLQueryItem]?
        if let period {
            queryItems = [URLQueryItem(name: "period", value: period.rawValue)]
        }
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.networthHistory, queryItems: queryItems)
        return try await perform(request)
    }
}

// MARK: - Private Helpers

private extension APIService {

    /// Build an authenticated URLRequest for requests with no body (GET, DELETE).
    func makeRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) async throws -> URLRequest {
        let urlString = APIConfiguration.url(for: endpoint)
        guard var components = URLComponents(string: urlString) else {
            throw APIError.unknown(-1)
        }
        if let queryItems {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.unknown(-1)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let token = try await tokenProvider.getToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            throw APIError.notAuthenticated
        }

        return request
    }

    /// Build an authenticated URLRequest with a JSON-encoded Codable body (POST, PUT).
    func makeRequest<B: Encodable>(
        endpoint: String,
        method: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> URLRequest {
        var request = try await makeRequest(endpoint: endpoint, method: method, queryItems: queryItems)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    /// Execute a request and decode the response body into T.
    /// Retries once with a force-refreshed token on 401.
    func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let endpoint = Self.endpointString(for: request)
        let (data, response) = try await execute(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            log.warn("401 — retrying with refreshed token", category: .api, context: ["endpoint": endpoint])
            let retryData = try await retryWithRefreshedToken(request)
            return try decodeResponse(T.self, from: retryData, endpoint: endpoint)
        }

        try validate(response: response, data: data, endpoint: endpoint)
        return try decodeResponse(T.self, from: data, endpoint: endpoint)
    }

    /// Execute a request that returns no body (e.g. DELETE 204).
    /// Retries once with a force-refreshed token on 401.
    func performVoid(_ request: URLRequest) async throws {
        let endpoint = Self.endpointString(for: request)
        let (data, response) = try await execute(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            log.warn("401 — retrying with refreshed token", category: .api, context: ["endpoint": endpoint])
            _ = try await retryWithRefreshedToken(request)
            return
        }

        try validate(response: response, data: data, endpoint: endpoint)
    }

    /// Wraps URLSession.data catching transport errors as APIError.networkError.
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let start = Date()
        let method = request.httpMethod ?? "GET"
        let endpoint = Self.endpointString(for: request)
        do {
            let (data, response) = try await session.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log.info(
                "HTTP \(method) completed",
                category: .api,
                context: ["endpoint": endpoint, "status": status, "durationMs": ms]
            )
            return (data, response)
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            log.error(
                "HTTP transport failed",
                error: error,
                category: .api,
                context: ["endpoint": endpoint, "method": method, "durationMs": ms]
            )
            throw APIError.networkError(error)
        }
    }

    /// Force-refreshes the Firebase token, re-signs the request, and executes it.
    /// If the retry also returns 401, posts `.authenticationRequired` and throws `.unauthorized`.
    func retryWithRefreshedToken(_ original: URLRequest) async throws -> Data {
        let endpoint = Self.endpointString(for: original)
        let freshToken: String
        do {
            freshToken = try await tokenProvider.getToken(forceRefresh: true)
        } catch {
            log.error(
                "Token refresh failed after 401",
                error: error,
                category: .api,
                context: ["endpoint": endpoint]
            )
            throw APIError.notAuthenticated
        }

        var retried = original
        retried.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")

        let (retryData, retryResponse) = try await execute(retried)

        if let http = retryResponse as? HTTPURLResponse, http.statusCode == 401 {
            log.error(
                "Persistent 401 after token refresh",
                error: APIError.unauthorized,
                category: .api,
                context: ["endpoint": endpoint, "case": APIError.unauthorized.logLabel]
            )
            NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            throw APIError.unauthorized
        }

        try validate(response: retryResponse, data: retryData, endpoint: endpoint)
        return retryData
    }

    /// Validate HTTP status code, throwing a mapped APIError on failure.
    func validate(response: URLResponse, data: Data, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else {
            let err = APIError.unknown(-1)
            log.error(
                "Invalid HTTP response",
                error: err,
                category: .api,
                context: ["endpoint": endpoint, "case": err.logLabel]
            )
            throw err
        }
        guard 200...299 ~= http.statusCode else {
            let err = APIError.from(statusCode: http.statusCode, data: data, decoder: decoder)
            log.error(
                "API HTTP error",
                error: err,
                category: .api,
                context: ["endpoint": endpoint, "status": http.statusCode, "case": err.logLabel]
            )
            throw err
        }
    }

    /// Decode response data, wrapping any decoding failure as APIError.decodingError.
    func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data, endpoint: String) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let err = APIError.decodingError(error)
            log.error(
                "API decode failed",
                error: error,
                category: .api,
                context: ["endpoint": endpoint, "case": err.logLabel]
            )
            throw err
        }
    }

    static func endpointString(for request: URLRequest) -> String {
        guard let url = request.url else { return "unknown" }
        let path = url.path
        if path.isEmpty {
            return url.absoluteString
        }
        if let query = url.query, !query.isEmpty {
            return "\(path)?\(query)"
        }
        return path
    }
}

// MARK: - Notification

extension Notification.Name {
    /// Posted when API authentication fails persistently (401 after token refresh).
    /// AuthManager observes this to sign the user out.
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
