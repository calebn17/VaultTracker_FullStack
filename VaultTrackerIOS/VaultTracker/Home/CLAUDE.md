# Home

Main dashboard screen. Net worth, asset breakdown, per-asset holdings, net worth history chart, price refresh, and add transaction.

> **State details, data flow, all key behaviors:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files

| File                      | Role                                                                   |
| ------------------------- | ---------------------------------------------------------------------- |
| `HomeView.swift`          | SwiftUI dashboard UI                                                   |
| `HomeViewModel.swift`     | State management, API orchestration                                    |
| `HomeViewWrapper.swift`   | Thin wrapper owning `@StateObject` (keeps previews clean)              |
| `NetWorthChartView.swift` | Line chart — pure display, receives `[NetWorthSnapshot]`, no ViewModel |
