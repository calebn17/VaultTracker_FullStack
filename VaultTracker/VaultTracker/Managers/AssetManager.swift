//
//  AssetManager.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/27/25.
//

import Foundation

enum CurrencySymbol: String {
    case usd = "USD"
    case eur = "EUR"
}
enum CryptoSymbol: String {
    case btc = "BTC"
    case eth = "ETH"
    case sol = "SOL"
}

// rethink this
// If we are going to pull symbols from the API, this might not be needed
enum StocksSymbol: String {
    case voo = "VOO"
    case schd = "SCHD"
    case schg = "SCHG"
    case amazon = "AMZN"
    case asml = "ASML"
    case google = "GOOGL"
}

protocol AssetManagerProtocol {
    func fetchCryptoAssetMarketData(symbol: String, currency: CurrencySymbol) async throws -> CryptoAssetResponse
    func fetchStocksAssetMarketData(symbol: String) async throws -> StocksAssetResponse
//    func getCryptoAssetPortfolioValue(
//        /*assetsArray: [Asset]*/
//        assetArray: [(String, Int)]
//    ) async throws -> Double
}

final class AssetManager: AssetManagerProtocol {
    // Maybe store this in Keychain in the future
    private let apiKey = "MTI6BQF066SXWM62"
    let stocksAndCryptoBaseUrl = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE"
    
    var networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService.sharedInstance) {
        self.networkService = networkService
    }
    
    func fetchCryptoAssetMarketData(symbol: String, currency: CurrencySymbol) async throws -> CryptoAssetResponse {
        let queryParams: [String: String] = [
            "function": "CURRENCY_EXCHANGE_RATE",
            "from_currency": symbol,
            "to_currency": currency.rawValue,
            "apikey": apiKey
        ]
        
        let response = try await networkService.performNetworkCall(
            urlString: stocksAndCryptoBaseUrl,
            method: .GET,
            queryParams: queryParams,
            headers: nil,
            body: nil,
            responseType: GlobalCryptoResponse.self
        )
        
        return response.data
    }
    
    func fetchStocksAssetMarketData(symbol: String) async throws -> StocksAssetResponse {
        let queryParams: [String: String] = [
            "function": "GLOBAL_QUOTE",
            "symbol": symbol,
            "apikey": apiKey
        ]
        
        let response = try await networkService.performNetworkCall(
            urlString: stocksAndCryptoBaseUrl,
            method: .GET,
            queryParams: queryParams,
            headers: nil,
            body: nil,
            responseType: GlobalStocksResponse.self
        )
        
        return response.data
    }
    
//    /// Makes call to API to fetch current price
//    /// Fetches amount of coins from store
//    /// Multiplies the two to get the total value held
//    func getCryptoAssetPortfolioValue(
//        assetsArray: [Asset]
//    ) async throws -> Double {
//        // I'm thinking whether to get the entire portfolio value here
//        // or do it separately per coin...
//        
//        var result = 0.0
//        
//        for i in 0..<assetsArray.count {
//            guard let asset = assetsArray[i],
//                  asset.category == .crypto
//            let response = try await fetchCryptoAssetMarketData(symbol: assetsArray[i].symbol, currency: .usd)
//            let price = Double(response.exchangeRate) ?? 0.0
//            let amount = Double(assetsArray[i].quantity)
//            result += (price * amount)
//            print("asset: \(assetsArray[i].0), price: \(price), amount: \(amount)")
//        }
//        
//        return result
//    }
//    
//    func test() async throws -> Double {
//        let assetArray: [(String, Int)] = [
//            ("BTC", 1),
//            ("ETH", 1)
//        ]
//        
//        return try await getCryptoAssetPortfolioValue(assetArray: assetArray)
//    }
}

