# VaultTrackerScanner

Personal, local tool to discover broker/CSV exports (and later images/PDFs), normalize them to `SmartTransactionCreate`-shaped payloads, and import via `POST /api/v1/transactions/smart` against a running VaultTracker API (typically `localhost:8000` with debug auth).

## Layout

- `inbox/` — default drop zone for files to import (contents are git-ignored; only `.gitkeep` is tracked).
- `processed/` — timestamped archives after a successful run (contents git-ignored).
- `src/vaulttracker_scanner/` — package source (pipeline stages added incrementally).
- **Contract:** `SmartTransactionPayload` and `validate_smart_payloads()` mirror `SmartTransactionCreate` in the API.
- **Discover:** `discover_manifest(dir)` groups `csv` / `pdf` / `image` paths (non-recursive).
- **CSV:** `parse_csv(path)` auto-detects Coinbase retail and Binance spot exports; pass `column_map={...}` for other layouts.
- **Normalize:** `normalize_raw_row` / `normalize_raw_rows` map `RawParsedRow` → smart payload dicts (category aliases, cash/real-estate $ encoding, dates).
- **Preview:** `format_preview_table(normalized, validation_errors)` for a markdown-style table + error list.
- **Import:** `import_smart_payloads(payloads, base_url=..., bearer_token=..., dry_run=...)` POSTs each item to `/api/v1/transactions/smart` (stdlib HTTP); inject `post_fn` in tests.
- **Archive:** `write_archive(processed_root, entries, timestamp=...)` writes `sources/`, `payloads/*.json`, `manifest.json`. Use `load_flat_payloads_for_reimport(archive_dir)` to reload payload arrays in manifest order.

## Setup (one-time)

From this directory, using Python 3.11+:

```bash
cd VaultTrackerScanner
python3 -m venv .venv
./.venv/bin/pip install -e ".[dev]"
```

(Agents in this repo may skip installs; use an existing venv and point `PYTHONPATH` at `src`, or run `pytest`/`ruff` from a machine where deps are already installed.)

## Commands

```bash
# From VaultTrackerScanner/ with dev deps installed
./.venv/bin/ruff format .
./.venv/bin/ruff check --select E,F,I .
./.venv/bin/python -m pytest tests/ -v

# Stub CLI (full pipeline in a later plan step)
./.venv/bin/vaulttracker-scan
./.venv/bin/python -m vaulttracker_scanner
```

## API expectations

- Base URL: `http://localhost:8000` (override when the CLI exposes flags).
- Debug auth header: `Authorization: Bearer vaulttracker-debug-user` with `DEBUG_AUTH_ENABLED=true` on the API.

See [`Documentation/Plans/2026-05-02-scanner-design.md`](../Documentation/Plans/2026-05-02-scanner-design.md) for the full pipeline design.
