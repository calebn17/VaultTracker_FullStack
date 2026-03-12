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
/// Auth header injection will be added in Phase 1.4 (AuthTokenProvider).
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
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.dashboard)
        return try await perform(request)
    }

    // MARK: - Accounts

    func fetchAccounts() async throws -> [APIAccountResponse] {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.accounts)
        return try await perform(request)
    }

    func createAccount(_ body: APIAccountCreateRequest) async throws -> APIAccountResponse {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.accounts, method: "POST", body: body)
        return try await perform(request)
    }

    func updateAccount(id: String, _ body: APIAccountUpdateRequest) async throws -> APIAccountResponse {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.account(id: id), method: "PUT", body: body)
        return try await perform(request)
    }

    func deleteAccount(id: String) async throws {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.account(id: id), method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Assets

    func fetchAssets() async throws -> [APIAssetResponse] {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.assets)
        return try await perform(request)
    }

    func fetchAsset(id: String) async throws -> APIAssetResponse {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.asset(id: id))
        return try await perform(request)
    }

    // MARK: - Transactions

    func fetchTransactions() async throws -> [APITransactionResponse] {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.transactions)
        return try await perform(request)
    }

    func createTransaction(_ body: APITransactionCreateRequest) async throws -> APITransactionResponse {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.transactions, method: "POST", body: body)
        return try await perform(request)
    }

    func updateTransaction(id: String, _ body: APITransactionUpdateRequest) async throws -> APITransactionResponse {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.transaction(id: id), method: "PUT", body: body)
        return try await perform(request)
    }

    func deleteTransaction(id: String) async throws {
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.transaction(id: id), method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Net Worth History

    func fetchNetWorthHistory(period: APINetWorthPeriod? = nil) async throws -> APINetWorthHistoryResponse {
        var queryItems: [URLQueryItem]? = nil
        if let period {
            queryItems = [URLQueryItem(name: "period", value: period.rawValue)]
        }
        let request = try makeRequest(endpoint: APIConfiguration.Endpoints.networthHistory, queryItems: queryItems)
        return try await perform(request)
    }
}

// MARK: - Private Helpers

private extension APIService {

    /// Build a URLRequest for requests with no body (GET, DELETE).
    func makeRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        let urlString = APIConfiguration.url(for: endpoint)
        guard var components = URLComponents(string: urlString) else {
            throw APIServiceError.invalidURL(urlString)
        }
        if let queryItems {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIServiceError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // TODO: Phase 1.4 — inject Authorization: Bearer <token> here via AuthTokenProvider
        return request
    }

    /// Build a URLRequest with a JSON-encoded Codable body (POST, PUT).
    func makeRequest<B: Encodable>(
        endpoint: String,
        method: String,
        body: B,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var request = try makeRequest(endpoint: endpoint, method: method, queryItems: queryItems)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    /// Execute a request and decode the response body into T.
    func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIServiceError.decodingError(error)
        }
    }

    /// Execute a request that returns no body (e.g. DELETE 204).
    func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    /// Validate HTTP status code, throwing a typed error on failure.
    func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200...299 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }
    }
}

// MARK: - APIServiceError

/// Errors thrown by APIService.
/// A full error type with user-facing messages will be added in Phase 1.5 (APIError.swift).
enum APIServiceError: Error {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
}
