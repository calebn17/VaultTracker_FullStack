---
name: vaulttracker-scan
description: >-
  Run the VaultTrackerScanner inbox pipeline (CSV via CLI; PDF/images via Read +
  JSON handoff), show preview, and require explicit user confirmation before
  live API import. Use when the user says /scan, scan inbox, import CSV
  statements, or bootstrap VaultTracker from exports.
---

# VaultTracker scan (`/scan`)

Personal workflow: ingest files under `VaultTrackerScanner/inbox/`, preview smart-transaction rows, optionally POST to the local API, then archive under `processed/`.

## Preconditions

- Repo path: `VaultTrackerScanner/` (scanner root for `--root`).
- API: `VaultTrackerAPI` running at `http://localhost:8000` with `DEBUG_AUTH_ENABLED=true` and Bearer `vaulttracker-debug-user` when doing real import.
- Python: 3.11+ recommended; package editable-installed (`pip install -e ".[dev]"` from `VaultTrackerScanner/`) or `PYTHONPATH=VaultTrackerScanner/src`.

## Hard gates

1. **Never** run `--apply` without a real HTTP target unless the user explicitly asked for a dry import (`--import-dry-run`) or preview-only.
2. After preview, **stop** and ask: *Proceed with live import (`--apply`), import dry-run (`--apply --import-dry-run`), or stop?*
3. Do not push secrets; do not log bearer tokens in chat.

## Phase A — CSV (deterministic)

1. Optionally list `VaultTrackerScanner/inbox/` (supported: `.csv`, `.pdf`, `.png`, `.jpg`, `.jpeg`, `.heic`).
2. Run **preview** (no network, no archive):

```bash
cd VaultTrackerScanner
python -m vaulttracker_scanner --root .
```

3. If stderr shows skipped PDFs/images, continue to Phase B for those paths only.
4. If validation errors appear in the preview table, fix source files or normalization inputs; re-run preview until clean (unless the user accepts partial manual fixes).
5. On user confirm for **live** import + archive:

```bash
python -m vaulttracker_scanner --root . --apply
```

6. For **synthetic** import ids + archive (no real POST):

```bash
python -m vaulttracker_scanner --root . --apply --import-dry-run
```

7. To skip writing `processed/`:

```bash
python -m vaulttracker_scanner --root . --apply --no-archive
```

CLI flags: `--inbox`, `--processed`, `--base-url`, `--token` (see `VaultTrackerScanner/README.md`).

## Phase B — PDF / image (vision handoff)

The CLI **does not** parse PDFs/images yet. For each skipped file:

1. Use the editor **Read** tool on the file path (vision-capable formats).
2. Extract rows matching the loose shape expected by `RawParsedRow` / `normalize_raw_rows` (see `vaulttracker_scanner.models.RawParsedRow` and `Documentation/Plans/2026-05-02-scanner-design.md`).
3. Save a JSON array to e.g. `VaultTrackerScanner/inbox/_vision_extract.json` (git-ignored with other inbox files).
4. Run the **snippet** in `VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md` (“Vision JSON snippet”) to preview; merge validated dicts into the user’s chosen next step (manual `import_smart_payloads` is optional until CLI absorbs JSON).

**Preferred shortcut:** If the user agrees, rewrite extracted trades as a **CSV** in `inbox/` that matches Coinbase/Binance headers or a generic layout plus documented `column_map` (see `parse_csv` docs in `README.md`), then re-run Phase A only.

## After import

- Point the user to the new `processed/<timestamp>/` directory (`manifest.json`, `sources/`, `payloads/`).
- Recovery: `load_flat_payloads_for_reimport` + `import_smart_payloads` (see `vaulttracker_scanner.archive` and design doc).

## References

- Design: `Documentation/Plans/2026-05-02-scanner-design.md`
- Deep workflow + JSON snippet: `VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md`
- CLI + layout: `VaultTrackerScanner/README.md`
