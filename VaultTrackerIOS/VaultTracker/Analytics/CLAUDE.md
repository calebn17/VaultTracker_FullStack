# Analytics

Second tab. Portfolio allocation by category and gain/loss performance from `GET /api/v1/analytics`.

> **Data flow, API models, display specs:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File | Role |
|------|------|
| `AnalyticsView.swift` | SwiftUI List UI — performance + allocation sections |
| `AnalyticsViewModel.swift` | Fetches analytics, maps to display state |

## ViewModel State

| Property | Type | Purpose |
|----------|------|---------|
| `allocationEntries` | `[(key: String, entry: APIAllocationEntry)]` | Sorted allocation rows |
| `performance` | `APIPerformanceBlock?` | Gain/loss summary; nil if no data |
| `isLoading` | `Bool` | Shows `.ultraThinMaterial` overlay |
| `errorMessage` | `String?` | Shown as red text in a List Section |
