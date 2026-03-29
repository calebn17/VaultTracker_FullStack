# Design Spec: "Digital Ledger" iOS Visual Redesign

## Context

The VaultTracker iOS app needs a visual redesign to match the "Digital Ledger" design language — a premium dark theme with lime green accents, monospaced financial typography, and tonal depth layering. This is a **view-only redesign**: no ViewModel, model, API, or business logic changes. All existing functionality is preserved. All `accessibilityIdentifier` values remain unchanged.

## Design Decisions (from user)

- **Tab structure**: Keep existing 3 tabs (Home, Analytics, Profile) — restyle only
- **Non-existent features**: Omit entirely (no "Link Bank", "Update Equity", "Monthly Report")
- **Add Asset modal**: Use reference visual style/layout but keep all current form fields (Buy/Sell, account, etc.)
- **Typography**: Use iOS system fonts (SF Pro + SF Mono) — no bundled custom fonts
- **Theme**: Dark-only (forced via `.preferredColorScheme(.dark)`)

## Design System

### Colors (`DesignSystem/VTColors.swift`)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#111317` | App-wide base background |
| `surfaceLow` | `#1A1D23` | Tab bar, asset bar bg, subtle containers |
| `surface` | `#22252B` | Cards, list row backgrounds |
| `surfaceHigh` | `#2A2D33` | Floating elements, secondary buttons |
| `primary` | `#C5F261` | CTAs, positive trends, selected states |
| `primaryDim` | `#AAD548` | Gradient end for primary buttons |
| `secondary` | `#70D2FF` | Stocks category color |
| `tertiary` | `#FFB77A` | Crypto category color |
| `error` | `#FFB4AB` | Negative values, destructive actions |
| `textPrimary` | `#FFFFFF` | Headers and hero values only |
| `textSubdued` | `#FFFFFF` @ 60% opacity | Body text, labels, secondary info |
| `ghostBorder` | `#FFFFFF` @ 15% opacity | Accessibility fallback borders only |

**Category color mapping:**

| Category | Color |
|----------|-------|
| `.stocks` | `secondary` (#70D2FF sky blue) |
| `.crypto` | `tertiary` (#FFB77A sunset orange) |
| `.cash` | `primary` (#C5F261 lime green) |
| `.realEstate` | `#E879F9` (orchid/magenta) |
| `.retirement` | `#A78BFA` (lavender) |

**No-border rule:** Boundaries defined solely through background color shifts and spacing. No 1px solid borders anywhere.

### Typography (`DesignSystem/VTTypography.swift`)

| Token | Font | Usage |
|-------|------|-------|
| `heroValue` | `.system(size: 40, weight: .bold, design: .rounded)` | Net worth hero display |
| `monoLarge` | `.system(size: 18, weight: .semibold, design: .monospaced)` | Asset values in lists |
| `monoBody` | `.system(size: 14, weight: .regular, design: .monospaced)` | Percentages, tickers |
| `monoCaption` | `.system(size: 12, weight: .regular, design: .monospaced)` | Small values, quantity text |
| `sectionHeader` | `.system(size: 13, weight: .semibold)` | Uppercased section labels |
| `body` | `.system(size: 14)` | General body text |
| `caption` | `.system(size: 12)` | Metadata, secondary info |

**The Data Rule:** All financial figures (dollar amounts, percentages, tickers) use monospaced design for decimal alignment.

### Components (`DesignSystem/VTComponents.swift`)

**`VTPrimaryButtonStyle`** — Pill-shaped (`Capsule`), lime green gradient background (`primary` → `primaryDim` at 135deg), dark charcoal text. Disabled state: 40% opacity.

**`SurfaceCardModifier`** — Applies tonal surface background + 16pt corner radius. Three levels: `.low`, `.standard`, `.high`. No borders.

**`FilterChipStyle`** — Category pills. Selected: `primary` background, `background` text color. Unselected: `surface` background, `textSubdued` text color. Capsule shape.

**`VTSecondaryButtonStyle`** — `surfaceHigh` background, `primary` text, capsule shape.

## Screen-by-Screen Changes

### VaultTrackerApp.swift

- Add `.preferredColorScheme(.dark)` to root view
- Set tab bar tint to `VTColors.primary` via `.tint()` modifier
- Configure `UINavigationBar.appearance()` in `init()`:
  - Background color: `VTColors.background`
  - Title text: white
- Configure `UITabBar.appearance()`:
  - Background: `VTColors.surfaceLow`
  - Unselected tint: `VTColors.textSubdued`

### LoadingView.swift

- Replace orange gradient background with solid `VTColors.background`
- Keep "VaultTracker" title text — white, large
- ProgressView tint: `VTColors.primary` (lime green)

### LoginView.swift

- Replace orange gradient with `VTColors.background` (ignores safe area)
- "VaultTracker" title: white, bold
- Google button: keep white bg / black text (Google branding requirement), 16pt corners
- Apple button: keep black bg / white text (Apple HIG), 16pt corners
- Debug button: `VTColors.surfaceHigh` background, `VTColors.primary` text, 16pt corners

### HomeView.swift (largest change)

**Background:** `VTColors.background.ignoresSafeArea()` on the ScrollView

**Error banner:**
- Background: `VTColors.error.opacity(0.15)`
- Text: `VTColors.error`
- Corner radius: 16
- Icon: `VTColors.error` instead of `.yellow`

**Filter bar:**
- Selected chip: `VTColors.primary` bg, `VTColors.background` text
- Unselected chip: `VTColors.surface` bg, `VTColors.textSubdued` text
- Keep `Capsule()` shape

**Period picker:**
- Configure UISegmentedControl appearance: selected segment tint `VTColors.primary`, selected text black, normal text white

**Net worth section:**
- Label: "TOTAL NET WORTH" (uppercased), `VTFonts.sectionHeader`, `VTColors.textSubdued`
- Value: `VTFonts.heroValue`, `VTColors.textPrimary`

**Asset bar:**
- Background: `VTColors.surfaceLow`
- Corner radius: 6
- Category segment colors: new palette

**Category cards (assetListSection):**
- Background: `VTColors.surface` (replacing `secondarySystemBackground`)
- Corner radius: 16 (replacing 10)
- Category dot: new palette colors
- Category name: `VTColors.textPrimary`
- Percentage: `VTFonts.monoBody`, `VTColors.primary`
- Dollar value: `VTFonts.monoLarge`, `VTColors.textPrimary`
- Chevron: `VTColors.textSubdued`
- Remove `Divider()` between header and expanded content (no-border rule)

**Expanded holdings:**
- Asset name/symbol: `VTFonts.monoBody`
- Value: `VTFonts.monoLarge`, bold
- Quantity: `VTFonts.monoCaption`, `VTColors.textSubdued`

**Aggregated asset list:**
- Same card styling: `VTColors.surface` bg, 16pt corners
- Monospaced fonts for values

**Loading overlay:**
- Background: `VTColors.background.opacity(0.7)` (replacing `black.opacity(0.05)`)
- ProgressView tint: `VTColors.primary`

**Toolbar:**
- Buttons tinted `VTColors.primary`
- "Clear Data" button: `VTColors.error` color

### NetWorthChartView.swift

- `LineMark` foreground: `VTColors.primary`, 2pt stroke width
- `AreaMark` gradient: `VTColors.primary.opacity(0.10)` → `Color.clear` (replacing blue)

### AddAssetModalView.swift

**Structure:** Keep `Form` but override appearance:
- `.scrollContentBackground(.hidden)` on the Form
- `.background(VTColors.background)` on outer container
- `.presentationBackground(VTColors.background)` on the sheet

**Category picker change** (only structural UI change):
- Replace native `Picker("Category")` with horizontal `ScrollView` of pill-shaped buttons
- Each button: `Capsule()` shape, selected uses `VTColors.primary` bg, unselected uses `VTColors.surface` bg
- Preserve `accessibilityIdentifier("categoryPicker")` on the container HStack
- Each chip's label matches `category.rawValue.capitalized` so UI tests still find buttons by label

**All other form fields:** Keep as-is functionally, apply:
- `.listRowBackground(VTColors.surface)` on each Section
- Text field text color: white
- Section header color: `VTColors.textSubdued`, uppercased

**Save button:**
- Capsule shape, `VTColors.primary` background, dark text
- Disabled: 40% opacity (replacing gray)
- Label: "Add Asset" (per reference) or keep "Save" — keeping "Save" since it's the existing label

**Close button:** Tint `VTColors.textSubdued`

**Date picker:** Tint `VTColors.primary`

### AnalyticsView.swift

- `.scrollContentBackground(.hidden)` + `.background(VTColors.background)`
- `.listRowBackground(VTColors.surface)` on all sections
- Performance values: `VTFonts.monoBody`
- Gain/loss: conditionally `VTColors.primary` (positive) or `VTColors.error` (negative)
- Allocation rows: add category color dot, values in `VTFonts.monoBody`, percentage in `VTFonts.monoCaption` + `VTColors.textSubdued`
- Loading overlay: `VTColors.background.opacity(0.7)` replacing `.ultraThinMaterial`

### ProfileView.swift

- Background: `VTColors.background.ignoresSafeArea()`
- Welcome text: `VTColors.textPrimary`
- Sign Out button: `Capsule()` shape, `VTColors.error` background, white text, 16pt corners

## Files Summary

### New files (3)
- `VaultTracker/DesignSystem/VTColors.swift`
- `VaultTracker/DesignSystem/VTTypography.swift`
- `VaultTracker/DesignSystem/VTComponents.swift`

### Modified files (9)
- `MainView/VaultTrackerApp.swift`
- `Loading/LoadingView.swift`
- `Login/LoginView.swift`
- `Home/HomeView.swift`
- `Home/NetWorthChartView.swift`
- `AddAssetModal/AddAssetModalView.swift`
- `Analytics/AnalyticsView.swift`
- `Profile/ProfileView.swift`
- `Utils/Extensions.swift` (add `Color(hex:)` initializer)

### Unchanged
- All ViewModels
- All Models
- All API layer files
- All Mappers
- DataService / DataServiceProtocol
- AuthManager / AuthTokenProvider
- Test files

## UI Test Considerations

- All `accessibilityIdentifier` values preserved exactly
- The AddAsset category picker change (Picker → horizontal chips) is the only structural risk. Mitigated by: keeping `accessibilityIdentifier("categoryPicker")` on the HStack, and ensuring each chip button label matches the category `rawValue.capitalized` so `app.buttons[category].firstMatch` still resolves
- After implementation: run UI tests to verify nothing breaks

## Verification Plan

1. Build the project in Xcode — confirm no compile errors
2. Run on simulator — verify each screen visually against reference images
3. Verify dark-only theme is forced correctly
4. Check all navigation flows (login → home → add asset → analytics → profile → sign out)
5. Verify filter chips, period picker, expandable categories all function correctly
6. Run existing UI tests (`VaultTrackerUITests`) to catch any broken identifiers
7. Check chart renders with new lime green styling
8. Verify Add Asset form validation still works with the restyled category chips
