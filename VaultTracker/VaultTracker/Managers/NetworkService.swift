//
//  NetworkManager.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import Foundation

enum HTTPMethod: String {
    case GET
    case PUT
    case POST
    case DELETE
}

protocol NetworkServiceProtocol {
    func performNetworkCall<T: Codable>(
        urlString: String,
        method: HTTPMethod,
        queryParams: [String: String]?,
        headers: [String: String]?,
        body: [String: String]?,
        responseType: T.Type
    ) async throws -> T
}

final class NetworkService: NetworkServiceProtocol {
    enum NetworkError: Error {
        case httpError(Int)
        case decodingError(Error)
        case noData
        
        var errorDescription: String? {
            switch self {
            case .httpError(let statusCode):
                return "HTTP Error: \(statusCode)"
            case .decodingError(let error):
                return "Decoding Error: \(error.localizedDescription)"
            case .noData:
                return "No data received"
            }
        }
    }
    
    static let sharedInstance = NetworkService()
    
    private init() {}
    
    func performNetworkCall<T: Codable>(
        urlString: String,
        method: HTTPMethod,
        queryParams: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let request = try buildRequest(httpMethod: method, urlString: urlString, queryParams: queryParams, headers: headers, body: body) else {
            throw RequestBuilderError.urlRequestNilError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            let result = try JSONDecoder().decode(responseType, from: data)
            return result
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    //MARK: - Helpers
    private enum RequestBuilderError: Error {
        case jsonSerializationFailed(Error)
        case createURLFailed
        case urlRequestNilError
        
        var errorDescription: String? {
            switch self {
            case .jsonSerializationFailed(let error):
                return "Failed to serialize JSON: \(error.localizedDescription)"
            case .createURLFailed:
                return "Failed to create URL from string"
            case .urlRequestNilError:
                return "Failed to build request"
            }
        }
    }
    
    private func buildRequest(
        httpMethod: HTTPMethod,
        urlString: String,
        queryParams: [String: String]? = nil,
        headers: [String: String]? = nil,
        body: [String: String]? = nil
    ) throws -> URLRequest? {
        guard var urlComponents = URLComponents(string: urlString) else {
            throw RequestBuilderError.createURLFailed
        }
        
        if let queryParams {
            urlComponents.queryItems = queryParams.map({ URLQueryItem(name: $0.key, value: $0.value) })
        }
        
        guard let url = urlComponents.url else {
            throw RequestBuilderError.createURLFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        if let headers {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body {
            do {
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = jsonData
            } catch let error{
                throw RequestBuilderError.jsonSerializationFailed(error)
            }
        }
        return request
    }
}
