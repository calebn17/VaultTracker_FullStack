# VaultTracker Scanner — Design Spec

## Context

VaultTracker currently requires manual entry of all financial data (accounts, assets, transactions) through the iOS or web clients. To bootstrap the database with historical data — brokerage statements, crypto exchange exports, and screenshots of account balances — a scanner tool is needed that can parse these documents and insert the extracted data automatically.

This is a personal tool for the repo owner, not a production feature for end users.

## Architecture

A Claude Code **skill** (`/scan`) orchestrates a pipeline of **Python scripts** (deterministic work) and a **Haiku agent** (vision parsing for images/PDFs). The scanner lives in `VaultTrackerScanner/` alongside the existing sub-projects.

- **Python scripts**: file discovery, CSV parsing, data normalization, validation, API insertion, archiving
- **Agent (Haiku)**: parses unstructured files (images, PDFs) via vision, presents preview, gets user confirmation
- **Auth**: debug token against local API (`localhost:8000` with `DEBUG_AUTH_ENABLED=true`)
- **Input**: default directory `VaultTrackerScanner/inbox/`, overridable via `/scan <path>`
- **Output**: transactions inserted via `POST /api/v1/transactions/smart`, artifacts archived to `processed/`

## Supported File Types

| Type | Extensions | Parser |
|------|-----------|--------|
| CSV | `.csv` | `parse_csv.py` (deterministic, format-aware) |
| PDF | `.pdf` | Agent vision via Read tool |
| Image | `.png`, `.jpg`, `.jpeg`, `.heic` | Agent vision via Read tool |

## Pipeline

```
/scan [path]
  │
  ├─ 1. discover.py ─── scan dir, group by type ──→ manifest
  │
  ├─ 2. PARSE (per file type)
  │   ├─ CSV  → parse_csv.py ──→ standardized JSON
  │   ├─ PDF  → Agent vision ──→ raw extracted data
  │   └─ IMG  → Agent vision ──→ raw extracted data
  │
  ├─ 3. normalize.py ─── map all parsed data → SmartTransactionCreate payloads
  │
  ├─ 4. validate.py ─── check required fields, enums, quantities
  │
  ├─ 5. PREVIEW ─── Agent presents combined table ─── user confirms/edits
  │
  ├─ 6. import.py ─── POST /api/v1/transactions/smart per payload
  │
  └─ 7. archive.py ─── archive sources + payloads + manifest
```

## Components

### `discover.py`

- **Input**: directory path (default `VaultTrackerScanner/inbox/`)
- **Behavior**: scans for supported extensions, groups by type
- **Output**: JSON `{ "csv": ["path1.csv", ...], "pdf": [...], "image": [...] }`
- **Error**: exits non-zero if directory empty or no supported files

### `parse_csv.py`

- **Input**: CSV file path + optional `--format` hint (e.g., `coinbase`, `binance`)
- **Behavior**:
  - Auto-detects known formats by column headers
  - Parses into standardized fields: `asset_name`, `symbol`, `category`, `quantity`, `price_per_unit`, `transaction_type`, `account_name`, `account_type`, `date`
  - Falls back to generic parsing if format unknown (agent assists with column mapping)
- **Output**: JSON array of parsed transactions
- **Known formats to support initially**: Coinbase, Binance (extend over time)

### Agent Vision (images + PDFs)

- Agent uses Claude Code's Read tool to view images/PDFs
- Extracts the same field set as CSV parser
- Handles: portfolio screenshots, trade confirmations, brokerage statement pages
- Returns raw extracted data as JSON for normalize.py

### `normalize.py`

- **Input**: raw parsed JSON (from any source — CSV parser or agent vision)
- **Behavior**:
  - Maps to `SmartTransactionCreate` schema
  - Normalizes category names (e.g., `"Crypto"` → `"crypto"`, `"Stocks/ETFs"` → `"stocks"`)
  - Normalizes dates to ISO 8601
  - Applies cash/real-estate encoding: `quantity = dollar_amount`, `price_per_unit = 1.0`
  - Maps account types to valid enum values: `cryptoExchange`, `brokerage`, `bank`, `retirement`, `other`
- **Output**: array of API-ready `SmartTransactionCreate` payloads

### `validate.py`

- **Input**: normalized payloads
- **Checks**:
  - Required fields present: `transaction_type`, `category`, `asset_name`, `quantity`, `price_per_unit`, `account_name`, `account_type`
  - `transaction_type` ∈ `{buy, sell}`
  - `category` ∈ `{crypto, stocks, cash, realEstate, retirement}`
  - `account_type` ∈ `{cryptoExchange, brokerage, bank, retirement, other}`
  - `quantity > 0`, `price_per_unit > 0`
  - `date` is valid ISO 8601 (if present)
- **Output**: `{ "valid": [...], "errors": [{ "index": N, "field": "...", "reason": "..." }] }`

### `import.py`

- **Input**: validated payloads JSON file
- **Behavior**:
  - Calls `POST http://localhost:8000/api/v1/transactions/smart` for each payload
  - Uses debug auth header: `Authorization: Bearer vaulttracker-debug-user`
  - Collects responses (inserted transaction IDs) or errors
- **Output**: `{ "inserted": [{ "payload_index": N, "id": "...", "asset": "...", "account": "..." }], "failed": [{ "payload_index": N, "error": "..." }] }`

### `archive.py`

- **Input**: source file paths, payload JSON files, import results
- **Behavior**: creates timestamped directory under `processed/`
- **Output** (archive structure):

```
processed/
  2026-05-02T14-30-00/
    sources/
      coinbase_export.csv
      crypto_screenshot.png
    payloads/
      coinbase_export.json
      crypto_screenshot.json
    manifest.json
```

- **`manifest.json`** schema:

```json
{
  "timestamp": "2026-05-02T14:30:00Z",
  "files": [
    {
      "source": "sources/coinbase_export.csv",
      "payload": "payloads/coinbase_export.json",
      "format": "coinbase_csv",
      "transactions_inserted": 5,
      "record_ids": ["uuid1", "uuid2", "..."]
    }
  ]
}
```

## Skill Definition

The `/scan` skill:
1. Accepts optional path argument (default: `VaultTrackerScanner/inbox/`)
2. Spawns a Haiku agent with pipeline instructions
3. Agent runs Python scripts via Bash tool for deterministic steps
4. Agent uses Read tool directly for image/PDF vision parsing
5. Agent presents combined preview table to user for confirmation
6. On confirm: runs `import.py` then `archive.py`
7. Reports summary: N transactions inserted, N failed, archive location

### Implemented (2026)

- **Cursor (project skill):** [`.cursor/skills/vaulttracker-scan/SKILL.md`](../../.cursor/skills/vaulttracker-scan/SKILL.md) — agent checklist, hard gates before `--apply`, CSV vs vision phases.
- **Operator + vision snippet:** [`VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md`](../../VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md) — CLI table, JSON handoff for PDFs/images, recovery pointers.
- **Deterministic runner:** `python -m vaulttracker_scanner` from `VaultTrackerScanner/` (see that folder’s `README.md`) implements discover → parse → normalize → validate → preview → import → archive in one process (replacing separate `import.py` / `archive.py` script names from this sketch).

## Data Flow Example

**Input**: `coinbase_export.csv` in inbox with Coinbase trade history

**After `parse_csv.py`**:
```json
[
  { "asset_name": "Bitcoin", "symbol": "BTC", "category": "crypto", "quantity": 0.5, "price_per_unit": 50000.0, "transaction_type": "buy", "account_name": "Coinbase", "account_type": "cryptoExchange", "date": "2024-01-15T10:30:00Z" }
]
```

**After `normalize.py`**: same structure, validated against `SmartTransactionCreate` schema

**Preview shown to user**:
```
| # | Asset   | Symbol | Qty  | Price   | Account  | Type | Date       |
|---|---------|--------|------|---------|----------|------|------------|
| 1 | Bitcoin | BTC    | 0.5  | 50,000  | Coinbase | buy  | 2024-01-15 |
```

**After `import.py`**: `POST /api/v1/transactions/smart` creates the transaction, auto-creating the "Coinbase" account and "Bitcoin" asset if they don't exist.

## Directory Structure

```
VaultTrackerScanner/
  inbox/                    # default drop zone for files to scan
  processed/                # archived imports (timestamped dirs)
  scripts/
    discover.py
    parse_csv.py
    normalize.py
    validate.py
    import.py
    archive.py
  formats/                  # CSV format definitions
    coinbase.py
    binance.py
    __init__.py
```

## Recovery Flow

If database data is lost:
1. Browse `processed/` for the relevant timestamped archive
2. Run `import.py` against files in the `payloads/` directory
3. All transactions are re-inserted without needing to re-parse source files

## Verification

1. Drop a sample CSV (Coinbase export) into `inbox/`
2. Run `/scan`
3. Verify preview table shows correct parsed data
4. Confirm insertion
5. Check API (`GET /api/v1/transactions`) to verify transactions exist
6. Check `processed/` for archived source + payloads + manifest
7. Delete the inserted transactions, re-run `import.py` against `payloads/` to verify recovery flow
