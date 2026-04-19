# Analytics — System Design

## Data Flow

```
.task { viewModel.load() }
    └─> DataService.fetchAnalytics()
        └─> APIService.fetchAnalytics()  →  APIAnalyticsResponse
            ├─> allocationEntries [(key, APIAllocationEntry)]  (sorted by key)
            └─> performance: APIPerformanceBlock?
```

Pull-to-refresh calls `load()` again.

## API Models (`API/Models/APIAnalyticsModels.swift`)

```swift
struct APIAllocationEntry: Codable { value, percentage }
struct APIPerformanceBlock: Codable { totalGainLoss, totalGainLossPercent, costBasis, currentValue }
struct APIAnalyticsResponse: Codable { allocation: [String: APIAllocationEntry], performance: APIPerformanceBlock }
```

`APIPerformanceBlock` uses camelCase keys because Pydantic serialises them that way — no custom `CodingKeys` needed.

## Display Specs

**Performance section** (shown only when `performance != nil`)

- Gain/loss (currency), gain/loss % (2 decimal places), cost basis (currency), current value (currency)

**Allocation section** — one row per category key (sorted alphabetically)

- Category name, current value (currency), percentage (2 decimal places, secondary style)
