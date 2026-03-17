//
//  APIConfiguration.swift
//  VaultTracker
//
//  Created by Claude on 1/11/26.
//

import Foundation

/// Defines the available API environments
enum APIEnvironment {
    case development
    case staging
    case production

    var baseURL: String {
        switch self {
        case .development:
            // Reads API_HOST from the Xcode scheme's environment variables so you
            // can switch between localhost (Simulator) and your Mac's LAN IP
            // (physical device) without touching source code.
            // Set API_HOST = 192.168.x.x:8000 in Edit Scheme → Run → Environment Variables.
            let host = ProcessInfo.processInfo.environment["API_HOST"] ?? "localhost:8000"
            return "http://\(host)"
        case .staging:
            // TODO: Update with staging URL when available
            return "http://localhost:8000"
        case .production:
            // TODO: Update with production URL when available
            return "http://localhost:8000"
        }
    }
}

/// Centralized API configuration for the VaultTracker app
enum APIConfiguration {

    // MARK: - Environment

    /// The current API environment. Change this to switch environments.
    static let environment: APIEnvironment = .development

    /// The base URL for all API requests
    static var baseURL: String {
        environment.baseURL
    }

    // MARK: - API Version

    /// The API version prefix
    static let apiVersion = "/api/v1"

    /// The full base path including version (e.g., "http://localhost:8000/api/v1")
    static var baseAPIPath: String {
        "\(baseURL)\(apiVersion)"
    }

    // MARK: - Endpoints

    enum Endpoints {
        // MARK: Health & Root

        /// GET / - API info
        static let root = "/"

        /// GET /health - Health check
        static let health = "/health"

        // MARK: Dashboard

        /// GET /api/v1/dashboard - Aggregated dashboard data
        static let dashboard = "\(apiVersion)/dashboard"

        // MARK: Accounts

        /// Base path for accounts: /api/v1/accounts
        static let accounts = "\(apiVersion)/accounts"

        /// Returns path for a specific account: /api/v1/accounts/{id}
        static func account(id: String) -> String {
            "\(accounts)/\(id)"
        }

        // MARK: Assets

        /// Base path for assets: /api/v1/assets
        static let assets = "\(apiVersion)/assets"

        /// Returns path for a specific asset: /api/v1/assets/{id}
        static func asset(id: String) -> String {
            "\(assets)/\(id)"
        }

        // MARK: Transactions

        /// Base path for transactions: /api/v1/transactions
        static let transactions = "\(apiVersion)/transactions"

        /// Returns path for a specific transaction: /api/v1/transactions/{id}
        static func transaction(id: String) -> String {
            "\(transactions)/\(id)"
        }

        // MARK: Net Worth History

        /// GET /api/v1/networth/history - Historical net worth snapshots
        static let networthHistory = "\(apiVersion)/networth/history"

        // MARK: Users

        /// DELETE /api/v1/users/me/data - Clear all financial data for the current user
        static let clearUserData = "\(apiVersion)/users/me/data"
    }

    // MARK: - Full URL Builders

    /// Constructs the full URL for an endpoint
    /// - Parameter endpoint: The endpoint path (e.g., "/api/v1/dashboard")
    /// - Returns: The complete URL string (e.g., "http://localhost:8000/api/v1/dashboard")
    static func url(for endpoint: String) -> String {
        "\(baseURL)\(endpoint)"
    }
}
