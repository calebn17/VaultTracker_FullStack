# Analytics

Second tab. Shows portfolio allocation by category and overall gain/loss performance sourced from `GET /api/v1/analytics`.

## Files

| File | Role |
|------|------|
| `AnalyticsView.swift` | SwiftUI List UI — performance section + allocation section |
| `AnalyticsViewModel.swift` | Fetches analytics, maps to display state |

## Data Flow

```
.task { viewModel.load() }
    └─> DataService.fetchAnalytics()
        └─> APIService.fetchAnalytics()  →  APIAnalyticsResponse
            ├─> allocationEntries [(key, APIAllocationEntry)]  (sorted by key)
            └─> performance: APIPerformanceBlock?
```

Pull-to-refresh calls `load()` again.

## Display

**Performance section** — shown only when `performance != nil`:
- Gain / loss (currency)
- Gain / loss % (two decimal places)
- Cost basis (currency)
- Current value (currency)

**Allocation section** — one row per category key (sorted alphabetically):
- Category name
- Current value (currency)
- Percentage (two decimal places, secondary style)

## API Models (in `API/Models/APIAnalyticsModels.swift`)

```swift
struct APIAllocationEntry: Codable { value, percentage }
struct APIPerformanceBlock: Codable { totalGainLoss, totalGainLossPercent, costBasis, currentValue }
struct APIAnalyticsResponse: Codable { allocation: [String: APIAllocationEntry], performance: APIPerformanceBlock }
```

`APIPerformanceBlock` uses camelCase keys because the backend (Pydantic) serialises them that way — no custom `CodingKeys` needed.

## ViewModel State

| Property | Type | Purpose |
|----------|------|---------|
| `allocationEntries` | `[(key: String, entry: APIAllocationEntry)]` | Sorted allocation rows |
| `performance` | `APIPerformanceBlock?` | Gain/loss summary; nil if no data |
| `isLoading` | `Bool` | Shows `.ultraThinMaterial` overlay |
| `errorMessage` | `String?` | Shown as red text in a List Section |
