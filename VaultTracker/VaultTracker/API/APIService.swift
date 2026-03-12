//
//  APIService.swift
//  VaultTracker
//
//  Created by Claude on 3/12/26.
//

import Foundation

/// Concrete implementation of APIServiceProtocol.
///
/// Uses URLSession directly (rather than the existing NetworkService) because
/// request bodies must be encoded from typed Codable structs, which NetworkService's
/// [String: String] body parameter cannot support.
///
/// All thrown errors are typed as `APIError` (see APIError.swift).
///
/// Auth flow: every request is sent with a Firebase JWT via AuthTokenProvider.
/// On a 401 response, the token is force-refreshed and the request retried once.
/// If authentication still fails after the retry, a `.authenticationRequired`
/// notification is posted so AuthManager can sign the user out.
final class APIService: APIServiceProtocol {

    // MARK: - Singleton

    static let shared = APIService()

    // MARK: - Private Properties

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Init

    private init(session: URLSession = .shared) {
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Dashboard

    func fetchDashboard() async throws -> APIDashboardResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.dashboard)
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

    func fetchAsset(id: String) async throws -> APIAssetResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.asset(id: id))
        return try await perform(request)
    }

    // MARK: - Transactions

    func fetchTransactions() async throws -> [APITransactionResponse] {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.transactions)
        return try await perform(request)
    }

    func createTransaction(_ body: APITransactionCreateRequest) async throws -> APITransactionResponse {
        let request = try await makeRequest(endpoint: APIConfiguration.Endpoints.transactions, method: "POST", body: body)
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

    // MARK: - Net Worth History

    func fetchNetWorthHistory(period: APINetWorthPeriod? = nil) async throws -> APINetWorthHistoryResponse {
        var queryItems: [URLQueryItem]? = nil
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
            let token = try await AuthTokenProvider.shared.getToken()
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
        let (data, response) = try await execute(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let retryData = try await retryWithRefreshedToken(request)
            return try decodeResponse(T.self, from: retryData)
        }

        try validate(response: response, data: data)
        return try decodeResponse(T.self, from: data)
    }

    /// Execute a request that returns no body (e.g. DELETE 204).
    /// Retries once with a force-refreshed token on 401.
    func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await execute(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            _ = try await retryWithRefreshedToken(request)
            return
        }

        try validate(response: response, data: data)
    }

    /// Wraps URLSession.data catching transport errors as APIError.networkError.
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Force-refreshes the Firebase token, re-signs the request, and executes it.
    /// If the retry also returns 401, posts `.authenticationRequired` and throws `.unauthorized`.
    func retryWithRefreshedToken(_ original: URLRequest) async throws -> Data {
        let freshToken: String
        do {
            freshToken = try await AuthTokenProvider.shared.getToken(forceRefresh: true)
        } catch {
            throw APIError.notAuthenticated
        }

        var retried = original
        retried.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")

        let (retryData, retryResponse) = try await execute(retried)

        if let http = retryResponse as? HTTPURLResponse, http.statusCode == 401 {
            NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            throw APIError.unauthorized
        }

        try validate(response: retryResponse, data: retryData)
        return retryData
    }

    /// Validate HTTP status code, throwing a mapped APIError on failure.
    func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(-1)
        }
        guard 200...299 ~= http.statusCode else {
            throw APIError.from(statusCode: http.statusCode, data: data, decoder: decoder)
        }
    }

    /// Decode response data, wrapping any decoding failure as APIError.decodingError.
    func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    /// Posted when API authentication fails persistently (401 after token refresh).
    /// AuthManager observes this to sign the user out.
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
