# Design System Specification: High-End Financial Intelligence

## 1. Overview & Creative North Star: "The Digital Ledger"
This design system is built to transform net-worth tracking from a chore into a premium editorial experience. Our Creative North Star is **The Digital Ledger**—a concept that blends the precision of Swiss banking with the atmospheric depth of modern high-performance interfaces.

We break the "standard app" template by rejecting rigid grids and heavy borders. Instead, we use **intentional asymmetry**, **monospaced data nodes**, and **tonal layering** to create an environment that feels expensive, private, and hyper-accurate. The UI doesn't just show data; it curates it.

## 2. Color Architecture
Our palette is rooted in a "void" black to ensure maximum contrast for financial growth indicators.

### The Foundation
*   **Background (`#111317`):** The absolute base. Everything grows from this dark substrate.
*   **Primary (`#FFFFFF`) & Primary Fixed (`#C5F261`):** Use pure white for high-level navigation and the neon lime green for growth-related actions and positive trends.
*   **Secondary & Tertiary:** Sky blue (`#70D2FF`) for traditional equities; Sunset orange (`#FFB77A`) for alternative assets/crypto.

### The "No-Line" Rule
**Strict Prohibition:** Designers are prohibited from using 1px solid borders to section off content.
Boundaries must be defined solely through:
1.  **Background Shifts:** Placing a `surface-container-low` card on a `surface` background.
2.  **Negative Space:** Using the `spacing-8` or `spacing-10` tokens to create breathing room between logical groups.
3.  **Tonal Transitions:** A subtle shift from `surface-dim` to `surface-bright`.

### Signature Textures
To provide "visual soul," use a subtle linear gradient on primary CTAs: 
`Linear-Gradient(135deg, primary-fixed #C5F261 0%, primary-fixed-dim #AAD548 100%)`.

## 3. Typography: The Editorial Balance
We utilize a dual-font approach to separate "Navigation" from "Intelligence."

| Level | Token | Font Family | Size | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | Space Grotesk | 3.5rem | Hero Net Worth totals. |
| **Headline** | `headline-md` | Space Grotesk | 1.75rem | Section headers / Portfolio names. |
| **Title** | `title-md` | Inter | 1.125rem | Card titles and primary labels. |
| **Body** | `body-md` | Inter | 0.875rem | Descriptions and secondary info. |
| **Label** | `label-md` | Inter | 0.75rem | Small metadata and button text. |

**The Data Rule:** All financial figures, percentages, and tickers must use a monospaced variant of the font or a dedicated mono-face to ensure that decimal points align vertically in lists, conveying a sense of mathematical "truth."

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are too "web 2.0." We achieve depth through a physical stacking model.

*   **The Layering Principle:** Treat the UI as stacked sheets of tinted glass. 
    *   *Base:* `surface`
    *   *Section:* `surface-container-low`
    *   *Card:* `surface-container`
    *   *Floating Element:* `surface-container-high`
*   **Glassmorphism:** For floating action buttons or sticky headers, use `surface-variant` at 40% opacity with a `20px` backdrop-blur. This allows the neon sparklines of the background to bleed through.
*   **The "Ghost Border" Fallback:** If accessibility requires a container definition, use the `outline-variant` token at **15% opacity**. It should be felt, not seen.
*   **Ambient Shadows:** For high-priority modals, use a shadow color tinted with `surface-tint` (`#AAD548`) at 5% opacity with a 40px blur. This creates a "glow" rather than a shadow.

## 5. Component Guidelines

### Buttons
*   **Primary:** Pill-shaped (`rounded-full`), using the Primary Gradient. Text is `on-primary` (Deep Charcoal).
*   **Secondary:** `surface-container-highest` background with `primary-fixed` text. No border.
*   **Tertiary:** Ghost style. No background, `on-surface-variant` text.

### The "Pulse" Card (Asset Tracking)
*   **Structure:** Never use divider lines between assets.
*   **Spacing:** Use `spacing-4` padding internally. 
*   **Visuals:** Use a `surface-container-low` background. The asset icon (Leading) should be high-contrast, while the secondary data (Trailing) should use `label-md` in `on-surface-variant`.

### Input Fields
*   **Style:** Minimalist underline or subtle `surface-container-lowest` fill. 
*   **Interaction:** On focus, the bottom border "blooms" into a `primary-fixed` neon lime glow.

### Financial Sparklines (Charts)
*   **Visual Style:** Use a 2px stroke width. 
*   **The "Vanish" Gradient:** Charts should have a subtle vertical gradient fill below the line, transitioning from `primary` (at 10% opacity) to `transparent` at the base.

## 6. Do's and Don'ts

### Do
*   **Do** use `space-grotesk` for large numbers to emphasize a modern, tech-forward aesthetic.
*   **Do** use `surface-container` nesting to group related financial instruments (e.g., all Bank Accounts inside one container).
*   **Do** embrace "The Void"—leave significant black space to make the neon accents pop.

### Don't
*   **Don't** use 100% opaque white text for everything. Reserve white for primary headers; use `on-surface-variant` (subdued grey) for everything else.
*   **Don't** use sharp corners. Use `rounded-lg` (16px) for cards and `rounded-sm` (4px) for tiny interactive chips.
*   **Don't** use standard red/green for everything. Use `primary-fixed` (#C5F261) for growth and `error` (#FFB4AB) for loss, but keep them desaturated unless they are the focal point.