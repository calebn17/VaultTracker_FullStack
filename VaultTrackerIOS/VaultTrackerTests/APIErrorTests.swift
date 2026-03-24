//
//  APIErrorTests.swift
//  VaultTrackerTests
//

import Testing
import Foundation
@testable import VaultTracker

@Suite("APIError")
struct APIErrorTests {

    private let decoder = JSONDecoder()

    // MARK: - HTTP Status Code Mapping

    @Test func status401MapsToUnauthorized() {
        let error = APIError.from(statusCode: 401, data: Data(), decoder: decoder)
        guard case .unauthorized = error else {
            Issue.record("Expected .unauthorized, got \(error)"); return
        }
    }

    @Test func status403MapsToForbidden() {
        let error = APIError.from(statusCode: 403, data: Data(), decoder: decoder)
        guard case .forbidden = error else {
            Issue.record("Expected .forbidden, got \(error)"); return
        }
    }

    @Test func status404MapsToNotFound() {
        let error = APIError.from(statusCode: 404, data: Data(), decoder: decoder)
        guard case .notFound = error else {
            Issue.record("Expected .notFound, got \(error)"); return
        }
    }

    @Test func status500MapsToServerError() {
        let error = APIError.from(statusCode: 500, data: Data(), decoder: decoder)
        guard case .serverError(let code) = error else {
            Issue.record("Expected .serverError, got \(error)"); return
        }
        #expect(code == 500)
    }

    @Test func status503MapsToServerError() {
        let error = APIError.from(statusCode: 503, data: Data(), decoder: decoder)
        guard case .serverError(let code) = error else {
            Issue.record("Expected .serverError, got \(error)"); return
        }
        #expect(code == 503)
    }

    @Test func unexpectedStatusMapsToUnknown() {
        let error = APIError.from(statusCode: 418, data: Data(), decoder: decoder)
        guard case .unknown(let code) = error else {
            Issue.record("Expected .unknown, got \(error)"); return
        }
        #expect(code == 418)
    }

    // MARK: - 422 Validation Error Parsing

    @Test func status422ParsesFastAPIValidationMessages() throws {
        let json = """
        {"detail":[{"loc":["body","name"],"msg":"field required","type":"value_error.missing"}]}
        """.data(using: .utf8)!

        let error = APIError.from(statusCode: 422, data: json, decoder: decoder)
        guard case .validationError(let messages) = error else {
            Issue.record("Expected .validationError, got \(error)"); return
        }
        #expect(messages.count == 1)
        #expect(messages.first?.contains("name") == true)
        #expect(messages.first?.contains("field required") == true)
    }

    @Test func status422WithInvalidJSONReturnsEmptyMessages() {
        let error = APIError.from(statusCode: 422, data: Data(), decoder: decoder)
        guard case .validationError(let messages) = error else {
            Issue.record("Expected .validationError, got \(error)"); return
        }
        #expect(messages.isEmpty)
    }

    @Test func status422WithMultipleFieldErrors() throws {
        let json = """
        {"detail":[
            {"loc":["body","name"],"msg":"field required","type":"value_error.missing"},
            {"loc":["body","category"],"msg":"invalid value","type":"value_error"}
        ]}
        """.data(using: .utf8)!

        let error = APIError.from(statusCode: 422, data: json, decoder: decoder)
        guard case .validationError(let messages) = error else {
            Issue.record("Expected .validationError, got \(error)"); return
        }
        #expect(messages.count == 2)
    }

    // MARK: - User-Facing Error Descriptions

    @Test func allErrorCasesHaveNonEmptyDescription() {
        let cases: [APIError] = [
            .notAuthenticated,
            .unauthorized,
            .forbidden,
            .notFound,
            .validationError(["name: field required"]),
            .validationError([]),
            .serverError(500),
            .networkError(URLError(.notConnectedToInternet)),
            .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "test"))),
            .unknown(418)
        ]
        for error in cases {
            #expect(error.errorDescription?.isEmpty == false, "errorDescription was empty for \(error)")
        }
    }

    @Test func serverErrorDescriptionIncludesCode() {
        let error = APIError.serverError(503)
        #expect(error.errorDescription?.contains("503") == true)
    }

    @Test func unknownErrorDescriptionIncludesCode() {
        let error = APIError.unknown(418)
        #expect(error.errorDescription?.contains("418") == true)
    }

    @Test func validationErrorDescriptionIncludesMessages() {
        let error = APIError.validationError(["email: invalid format"])
        #expect(error.errorDescription?.contains("email: invalid format") == true)
    }
}
