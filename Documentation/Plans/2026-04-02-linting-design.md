# Linting & Formatting Design — VaultTracker CI

**Date:** 2026-04-02
**Branch:** `add-ios-logging` → target: `main`
**Status:** Approved, pending implementation

---

## Problem

VaultTracker has three sub-projects (API, iOS, Web) with existing unit test CI jobs but no linting or formatting enforcement. Code quality and style consistency is currently unchecked at the PR level. The goal is to add automated lint and format checks that run **before** unit tests in CI, blocking PRs on serious violations and surfacing style nits as PR comments without blocking.

---

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CI structure | Dedicated `lint-*` jobs before test jobs | Clean separation; distinct status checks per sub-project |
| API tool | Ruff (lint + format) | Single tool replaces flake8 + black + isort; fast; Python 3.11 native |
| iOS tool | SwiftLint | Industry standard; native error/warning severity tiers; reviewdog support |
| Web tools | ESLint (already configured) + Prettier | ESLint handles logic; Prettier handles formatting objectively |
| Error surfacing | reviewdog | Posts PR review comments (priority) + GitHub Check annotations (secondary) |
| Blocking vs warning | Formatters = hard block; linter errors = hard block; linter warnings = comment only | Objective formatting has no ambiguity; subjective style nits shouldn't block |
| Runners | `ubuntu-latest` for API + Web; `macos-latest` for iOS | iOS requires macOS; Ubuntu is 10× cheaper for the others. Flip via comment when self-hosted Mac runners are available. |
| Existing violations | Fix upfront with one cleanup commit | Avoids baseline file complexity; formatters automate most of it |

---

## Severity Tiers

### API (Ruff)

| Tier | Rules | Behavior |
|---|---|---|
| Hard block | `ruff format --check .` | Any formatting mismatch fails the job |
| Hard block | `ruff check --select E,F,I` | Syntax errors, undefined names, unused imports, import sort |
| Warn | `ruff check --select W,C90,N --exit-zero` | Style, complexity, naming — posted as PR comments, job passes |

### iOS (SwiftLint)

| Tier | Config | Behavior |
|---|---|---|
| Hard block | Rules set to `error` severity in `.swiftlint.yml` | SwiftLint exits non-zero; job fails |
| Warn | Rules set to `warning` severity (default for most rules) | SwiftLint exits 0; reviewdog posts PR comments |

### Web

| Tier | Tool | Behavior |
|---|---|---|
| Hard block | `prettier --check .` | Any formatting mismatch fails the job |
| Hard block | ESLint rules as `"error"` | Job fails; reviewdog posts blocking annotation |
| Warn | ESLint rules as `"warn"` | Job passes; reviewdog posts informational PR comment |

---

## CI Job Structure

```
changes (paths-filter, ubuntu-latest)
    │
    ├──[api changed]──> lint-api (ubuntu-latest) ──> test-api (macos-latest)
    │
    ├──[ios changed]──> lint-ios (macos-latest)  ──> test-ios (macos-latest)
    │
    └──[web changed]──> lint-web (ubuntu-latest) ──> test-web (macos-latest)
```

Test jobs use `always() && needs.changes.outputs.<sub> == 'true' && needs.lint-<sub>.result == 'success'` — so tests only run when both changes are detected AND lint passed.

---

## Files to Create / Modify

| File | Action |
|---|---|
| `.github/workflows/ci.yml` | Add `lint-api`, `lint-ios`, `lint-web` jobs; update `needs` + `if` on test jobs |
| `VaultTrackerAPI/pyproject.toml` | Create — Ruff lint + format config |
| `VaultTrackerIOS/VaultTracker/.swiftlint.yml` | Create — SwiftLint rules with error/warning tiers |
| `VaultTrackerWeb/.prettierrc` | Create — Prettier config |
| `VaultTrackerWeb/eslint.config.mjs` | Update — add `warn`-level rules for style nits |

---

## Tool Configurations

### `VaultTrackerAPI/pyproject.toml`

```toml
[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "W", "C90", "N"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

### `VaultTrackerIOS/VaultTracker/.swiftlint.yml`

```yaml
opt_in_rules:
  - empty_count
  - closure_spacing
  - unused_import

disabled_rules:
  - trailing_whitespace  # SwiftLint autocorrect handles this

force_cast: error
force_try: error
implicitly_unwrapped_optional: error

line_length:
  warning: 120
  error: 200

file_length:
  warning: 400
  error: 600
```

### `VaultTrackerWeb/.prettierrc`

```json
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2
}
```

### `VaultTrackerWeb/eslint.config.mjs` additions

```js
{
  rules: {
    "no-console": "warn",
    "prefer-const": "warn",
    "no-unused-vars": "warn",
  }
}
```

---

## CI YAML — Lint Jobs

### `lint-api`

```yaml
lint-api:
  needs: changes
  if: needs.changes.outputs.api == 'true'
  runs-on: ubuntu-latest  # flip to macos-latest or self-hosted when Mac runners available
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with:
        python-version: '3.11'
    - name: Install ruff
      run: pip install ruff
    - name: Check formatting (hard block)
      working-directory: VaultTrackerAPI
      run: ruff format --check .
    - uses: reviewdog/action-setup@v1
    - name: Lint — blocking rules (E, F, I)
      working-directory: VaultTrackerAPI
      env:
        REVIEWDOG_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        set -o pipefail
        ruff check . --select E,F,I --output-format=github \
          | reviewdog -f=ruff -reporter=github-pr-review -reporter=github-check -fail-on-error=true
    - name: Lint — warning rules (W, C, N)
      working-directory: VaultTrackerAPI
      env:
        REVIEWDOG_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        ruff check . --select W,C90,N --exit-zero --output-format=github \
          | reviewdog -f=ruff -reporter=github-pr-review -reporter=github-check -fail-on-error=false
```

### `lint-ios`

```yaml
lint-ios:
  needs: changes
  if: needs.changes.outputs.ios == 'true'
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install SwiftLint
      run: brew install swiftlint
    - uses: reviewdog/action-setup@v1
    - name: Lint (SwiftLint — errors block, warnings comment)
      working-directory: VaultTrackerIOS/VaultTracker
      env:
        REVIEWDOG_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        swiftlint lint \
          | reviewdog -f=swiftlint -reporter=github-pr-review -reporter=github-check -fail-on-error=true
```

### `lint-web`

```yaml
lint-web:
  needs: changes
  if: needs.changes.outputs.web == 'true'
  runs-on: ubuntu-latest  # flip to macos-latest or self-hosted when Mac runners available
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
    - name: Install dependencies
      working-directory: VaultTrackerWeb
      run: npm ci
    - name: Check formatting (hard block)
      working-directory: VaultTrackerWeb
      run: npx prettier --check .
    - uses: reviewdog/action-setup@v1
    - name: Lint (ESLint via reviewdog)
      working-directory: VaultTrackerWeb
      env:
        REVIEWDOG_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        npx eslint . --format=json \
          | reviewdog -f=eslint -reporter=github-pr-review -reporter=github-check -fail-on-error=true
```

### Updated test job `needs` + `if`

```yaml
test-api:
  needs: [changes, lint-api]
  if: always() && needs.changes.outputs.api == 'true' && needs.lint-api.result == 'success'

test-ios:
  needs: [changes, lint-ios]
  if: always() && needs.changes.outputs.ios == 'true' && needs.lint-ios.result == 'success'

test-web:
  needs: [changes, lint-web]
  if: always() && needs.changes.outputs.web == 'true' && needs.lint-web.result == 'success'
```

---

## Upfront Cleanup (run locally before CI wiring)

```bash
# API
cd VaultTrackerAPI && pip install ruff
ruff format .
ruff check --fix --select E,F,I .

# Web
cd VaultTrackerWeb
npm install --save-dev prettier
npx prettier --write .

# iOS
brew install swiftlint
cd VaultTrackerIOS/VaultTracker && swiftlint --fix
```

Commit as: `chore: auto-fix lint and formatting violations before CI enforcement`

---

## Verification

1. PR with an unformatted Python file → `lint-api` fails on format check; `test-api` skipped
2. PR with a `print()` call in Python → `lint-api` passes; reviewdog posts a warning comment
3. PR with `force_cast` in Swift → `lint-ios` fails; `test-ios` skipped
4. PR touching only Web files → only `lint-web` and `test-web` run
5. PR touching only a root file (e.g. `CLAUDE.md`) → all jobs skipped (no path-filter match)
