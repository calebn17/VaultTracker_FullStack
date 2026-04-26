# FIRE

Third tab (flame icon). FIRE calculator aligned with the web `/fire` route.

## Behavior

- **Solo user:** Loads personal `GET /api/v1/fire/profile` and `GET /api/v1/fire/projection`, shows projection summary (targets, months to FIRE, surplus) and editable assumptions. Save runs `PUT /fire/profile` then refetches projection.
- **Household member:** Loads shared `GET /api/v1/households/me/fire-profile` only; shows a banner that combined multi-year projection is not available. Save runs `PUT /households/me/fire-profile` with the same `APIFIREProfileInput` shape as personal.

## Files

| File                | Role                                                        |
| ------------------- | ----------------------------------------------------------- |
| `FIREView.swift`     | List-based UI, accessibility IDs for `fire*`              |
| `FIREViewModel.swift` | `DataService` branch on `fetchHousehold() != nil`        |

## Tests

`VaultTrackerTests/FIREViewModelTests.swift` — unit tests with `MockDataService` (solo vs household load/save paths).
