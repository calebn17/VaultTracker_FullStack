//
//  AssetResponse.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/28/25.
//

import Foundation

struct GlobalStocksResponse: Codable {
    let data: StocksAssetResponse
    
    enum CodingKeys: String, CodingKey {
        case data = "Global Quote"
    }
}

struct StocksAssetResponse: Codable {
    let symbol: String
    let open: String
    let high: String
    let low: String
    let price: String
    let volume: String
    let latestTradingDay: String
    let previousClose: String
    let change: String
    let changePercent: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case open = "02. open"
        case high = "03. high"
        case low = "04. low"
        case price = "05. price"
        case volume = "06. volume"
        case latestTradingDay = "07. latest trading day"
        case previousClose = "08. previous close"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

struct GlobalCryptoResponse: Codable {
    
    let data: CryptoAssetResponse
    
    enum CodingKeys: String, CodingKey {
        case data = "Realtime Currency Exchange Rate"
    }
}

struct CryptoAssetResponse: Codable {
    let fromCurrencyCode: String
    let fromCurrencyName: String
    let toCurrencyCode: String
    let toCurrencyName: String
    let exchangeRate: String
    let lastRefreshed: String
    let timeZone: String
    let bidPrice: String
    let askPrice: String
    
    enum CodingKeys: String, CodingKey {
        case fromCurrencyCode = "1. From_Currency Code"
        case fromCurrencyName = "2. From_Currency Name"
        case toCurrencyCode = "3. To_Currency Code"
        case toCurrencyName = "4. To_Currency Name"
        case exchangeRate = "5. Exchange Rate"
        case lastRefreshed = "6. Last Refreshed"
        case timeZone = "7. Time Zone"
        case bidPrice = "8. Bid Price"
        case askPrice = "9. Ask Price"
    }
}

//"Realtime Currency Exchange Rate": {
//        "1. From_Currency Code": "BTC",
//        "2. From_Currency Name": "Bitcoin",
//        "3. To_Currency Code": "USD",
//        "4. To_Currency Name": "United States Dollar",
//        "5. Exchange Rate": "107174.75000000",
//        "6. Last Refreshed": "2025-06-28 14:14:07",
//        "7. Time Zone": "UTC",
//        "8. Bid Price": "107170.63400000",
//        "9. Ask Price": "107179.39600000"
//    }

// For later
//var lastRefreshedDate: Date? {
//    let formatter = DateFormatter()
//    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//    formatter.timeZone = TimeZone(identifier: timeZone)
//    return formatter.date(from: lastRefreshed)
//}
