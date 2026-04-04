//
//  APIServiceTests.swift
//  VaultTrackerTests
//

import Foundation
import Testing
@testable import VaultTracker

/// Intercepts HTTP for `URLSession` injected into `APIService` in unit tests.
private final class StubURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _handler = newValue
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self._handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("APIService", .serialized)
struct APIServiceTests {

    fileprivate let dashboardJSON = Data(
        """
        {"totalNetWorth":0,"categoryTotals":{"crypto":0,"stocks":0,"cash":0,"realEstate":0,"retirement":0},"groupedHoldings":{}}
        """.utf8
    )
}

#if DEBUG
extension APIServiceTests {

    /// Creates a debug `AuthTokenProvider` that bypasses Firebase — isolated per test to avoid global state races.
    private func makeDebugProvider() -> AuthTokenProvider {
        let provider = AuthTokenProvider.test_make(log: VTLoggingSpy())
        provider.isDebugSession = true
        return provider
    }

    private func makeService(log: any VTLogging, tokenProvider: AuthTokenProvider? = nil) -> APIService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return APIService.test_make(session: session, log: log, tokenProvider: tokenProvider ?? makeDebugProvider())
    }

    @Test func fetchDashboardSuccessLogsAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, dashboardJSON)
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        let dashboard = try await api.fetchDashboard()
        #expect(dashboard.totalNetWorth == 0)

        let infos = spy.entries.filter { $0.level == .info }
        #expect(infos.count == 1)
        #expect(infos[0].message == "HTTP GET completed")
        #expect(infos[0].context?["endpoint"] == "/api/v1/dashboard")
        #expect(infos[0].context?["status"] == "200")
    }

    @Test func fetchDashboardNon2xxLogsAPIError() async throws {
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        await #expect(throws: APIError.self) {
            try await api.fetchDashboard()
        }

        let errors = spy.entries.filter { $0.level == .error }
        #expect(errors.contains { $0.message == "API HTTP error" })
        #expect(spy.entries.contains { $0.level == .info && $0.context?["status"] == "500" })
    }

    @Test func fetchDashboard401Then200RetriesAndLogsWarn() async throws {
        let body = dashboardJSON
        var callCount = 0
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            callCount += 1
            if callCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        let dashboard = try await api.fetchDashboard()
        #expect(callCount == 2)
        #expect(dashboard.totalNetWorth == 0)

        let warns = spy.entries.filter { $0.level == .warn }
        #expect(warns.count == 1)
        #expect(warns[0].message == "401 — retrying with refreshed token")
        #expect(warns[0].context?["endpoint"] == "/api/v1/dashboard")

        let infos = spy.entries.filter { $0.level == .info }
        #expect(infos.count == 2)
        #expect(infos[0].context?["status"] == "401")
        #expect(infos[1].context?["status"] == "200")
    }

    @Test func transportFailureLogsAndMapsToNetworkError() async throws {
        StubURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        await #expect(throws: APIError.self) {
            try await api.fetchDashboard()
        }

        let errors = spy.entries.filter { $0.level == .error }
        #expect(errors.contains { $0.message == "HTTP transport failed" })
    }

    @Test func decodeFailureLogsDecodingError() async throws {
        let badJSON = Data(#"{"unexpected":true}"#.utf8)
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, badJSON)
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        await #expect(throws: APIError.self) {
            try await api.fetchDashboard()
        }

        let errors = spy.entries.filter { $0.level == .error }
        #expect(errors.contains { $0.message == "API decode failed" })
    }

    @Test func clearAllData204PerformVoidSucceedsAndLogs() async throws {
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            #expect(request.httpMethod == "DELETE")
            #expect(url.path == "/api/v1/users/me/data")
            let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        try await api.clearAllData()

        let infos = spy.entries.filter { $0.level == .info }
        #expect(infos.count == 1)
        #expect(infos[0].message == "HTTP DELETE completed")
        #expect(infos[0].context?["endpoint"] == "/api/v1/users/me/data")
        #expect(infos[0].context?["status"] == "204")
    }

    @Test func persistent401AfterRefreshLogsAndPostsNotification() async throws {
        var callCount = 0
        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { StubURLProtocol.handler = nil }

        var authNotifications = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .authenticationRequired,
            object: nil,
            queue: nil
        ) { _ in
            authNotifications += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy)
        do {
            try await api.fetchDashboard()
            Issue.record("Expected APIError.unauthorized")
        } catch let error as APIError {
            if case .unauthorized = error {
                // expected
            } else {
                Issue.record("Expected .unauthorized, got \(error)")
            }
        } catch {
            Issue.record("Expected APIError, got \(error)")
        }

        #expect(callCount == 2)
        #expect(authNotifications == 1)
        #expect(spy.entries.contains { $0.message == "Persistent 401 after token refresh" })
    }

    @Test func tokenRefreshFailureAfter401LogsNotAuthenticated() async throws {
        let provider = makeDebugProvider()
        provider.forceTokenRefreshFailure = true

        StubURLProtocol.handler = { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { StubURLProtocol.handler = nil }

        let spy = VTLoggingSpy()
        let api = makeService(log: spy, tokenProvider: provider)
        do {
            try await api.fetchDashboard()
            Issue.record("Expected APIError.notAuthenticated")
        } catch let error as APIError {
            if case .notAuthenticated = error {
                // expected
            } else {
                Issue.record("Expected .notAuthenticated, got \(error)")
            }
        } catch {
            Issue.record("Expected APIError, got \(error)")
        }

        #expect(spy.entries.contains { $0.message == "Token refresh failed after 401" })
    }
}
#endif
