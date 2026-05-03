# VaultTrackerScanner — agent workflow (`/scan`)

This document complements the Cursor skill at [`.cursor/skills/vaulttracker-scan/SKILL.md`](../../.cursor/skills/vaulttracker-scan/SKILL.md). It is the **canonical handoff** for PDF/image extraction and for operators who do not use Cursor skills.

## CSV-only automation (CLI)

From `VaultTrackerScanner/`:

| Goal | Command |
|------|---------|
| Preview (no HTTP) | `python -m vaulttracker_scanner --root .` |
| Live POST + archive | `python -m vaulttracker_scanner --root . --apply` |
| Dry import ids + archive | `python -m vaulttracker_scanner --root . --apply --import-dry-run` |
| Live POST, no archive dir | `python -m vaulttracker_scanner --root . --apply --no-archive` |

Override API host or token with `--base-url` and `--token`. Inbox/processed default to `<root>/inbox` and `<root>/processed`.

## Vision JSON snippet (PDF / HEIC / PNG)

Save an array of objects with fields compatible with `RawParsedRow` (see `vaulttracker_scanner.models`) to `inbox/_vision_extract.json`, then from `VaultTrackerScanner/`:

```bash
PYTHONPATH=src python -c "
import json
from pathlib import Path
from vaulttracker_scanner.normalize import normalize_raw_rows
from vaulttracker_scanner.preview import format_preview_table
from vaulttracker_scanner.validate import validate_smart_payloads_indexed

raw = json.loads(Path('inbox/_vision_extract.json').read_text(encoding='utf-8'))
norms = normalize_raw_rows(raw)
indexed, errs = validate_smart_payloads_indexed(norms)
print(format_preview_table(norms, errs))
print('---')
print('valid rows:', len(indexed), 'errors:', len(errs))
"
```

To POST only after the user confirms (same pattern as CLI, **no archive** unless you add it):

```bash
PYTHONPATH=src python -c "
import json
from pathlib import Path
from vaulttracker_scanner.import_payloads import import_smart_payloads
from vaulttracker_scanner.normalize import normalize_raw_rows
from vaulttracker_scanner.validate import validate_smart_payloads_indexed

raw = json.loads(Path('inbox/_vision_extract.json').read_text(encoding='utf-8'))
norms = normalize_raw_rows(raw)
indexed, errs = validate_smart_payloads_indexed(norms)
assert not errs
payloads = [p for _, p in indexed]
r = import_smart_payloads(payloads, dry_run=True)
print(r.model_dump())
"
```

Replace `dry_run=True` with `dry_run=False` only after explicit user consent and with the API running.

## Alternative: CSV in `inbox/`

If extraction is easier as a table, write `inbox/manual.csv` with headers compatible with `parse_csv` (Coinbase/Binance auto-detect) or use a generic CSV plus the `column_map` argument in a small script—see `vaulttracker_scanner.csv_parser.parse_csv` docstring in code.

## Verification checklist (agent)

1. Drop or generate inputs under `inbox/`.
2. Run preview CLI; confirm table matches user expectations.
3. Obtain explicit user choice: stop / dry import / live import.
4. If live import: confirm API debug auth is intended for this environment.
5. After success, show `processed/` path and `manifest.json` summary.
