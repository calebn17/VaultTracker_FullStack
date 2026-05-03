"""CLI: discover → parse → normalize → validate → preview → import → archive."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Mapping
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from vaulttracker_scanner.archive import ArchiveError, SourceArchiveEntry, write_archive
from vaulttracker_scanner.csv_parser import CsvParseError, iter_csv_paths, parse_csv
from vaulttracker_scanner.discover import DiscoverError, discover_manifest
from vaulttracker_scanner.import_payloads import (
    DEFAULT_BASE_URL,
    DEFAULT_BEARER_TOKEN,
    ImportBatchResult,
    import_smart_payloads,
)
from vaulttracker_scanner.normalize import NormalizeError, normalize_raw_rows
from vaulttracker_scanner.preview import format_preview_table
from vaulttracker_scanner.validate import validate_smart_payloads_indexed


def _record_ids_for_file_span(
    start: int,
    end: int,
    indexed_valid: list[tuple[int, dict[str, Any]]],
    import_result: ImportBatchResult,
) -> list[str]:
    batch_by_orig = {orig: b for b, (orig, _) in enumerate(indexed_valid)}
    id_by_batch = {ins.payload_index: ins.id for ins in import_result.inserted}
    rids: list[str] = []
    for orig in range(start, end):
        b_idx = batch_by_orig.get(orig)
        if b_idx is None:
            continue
        tid = id_by_batch.get(b_idx)
        if tid:
            rids.append(tid)
    return rids


def _warn_skipped_non_csv(manifest: Mapping[str, list[str]], *, inbox: Path) -> None:
    for key in ("pdf", "image"):
        for rel in manifest.get(key, []):
            print(
                f"Skipping {key.upper()} (not implemented in CLI): {inbox / rel}",
                file=sys.stderr,
            )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="vaulttracker-scan",
        description="Discover CSVs in an inbox, normalize to smart payloads, validate, "
        "and optionally POST to the VaultTracker API.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="Scanner project root (default: current working directory)",
    )
    parser.add_argument(
        "--inbox",
        type=Path,
        default=None,
        help="Inbox directory (default: <root>/inbox)",
    )
    parser.add_argument(
        "--processed",
        type=Path,
        default=None,
        help="Archive parent directory (default: <root>/processed)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="POST validated rows to the API (default: preview only, no HTTP)",
    )
    parser.add_argument(
        "--import-dry-run",
        action="store_true",
        help=(
            "When set with --apply, use import dry_run (synthetic ids), not real POST"
        ),
    )
    parser.add_argument(
        "--no-archive",
        action="store_true",
        help="After a successful import run, skip writing processed/ archive",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help=f"API base URL (default: {DEFAULT_BASE_URL})",
    )
    parser.add_argument(
        "--token",
        default=DEFAULT_BEARER_TOKEN,
        help="Bearer token for Authorization header",
    )

    args = parser.parse_args(argv)

    root = (args.root or Path.cwd()).expanduser().resolve()
    inbox = (args.inbox or (root / "inbox")).expanduser().resolve()
    processed_root = (args.processed or (root / "processed")).expanduser().resolve()

    try:
        manifest = discover_manifest(inbox)
    except DiscoverError as exc:
        print(f"discover: {exc}", file=sys.stderr)
        return 1

    _warn_skipped_non_csv(manifest, inbox=inbox)

    if not manifest.get("csv"):
        print("No CSV files in inbox — nothing to parse.", file=sys.stderr)
        return 0

    file_spans: list[tuple[Path, str, int, int]] = []
    all_norm: list[dict[str, Any]] = []

    for csv_path in iter_csv_paths(manifest, root=inbox):
        try:
            parsed = parse_csv(csv_path)
        except (CsvParseError, OSError) as exc:
            print(f"parse {csv_path}: {exc}", file=sys.stderr)
            return 1
        try:
            batch = normalize_raw_rows(parsed.rows)
        except NormalizeError as exc:
            print(f"normalize {csv_path}: {exc}", file=sys.stderr)
            return 1
        start = len(all_norm)
        all_norm.extend(batch)
        file_spans.append((csv_path, parsed.format_name, start, len(all_norm)))

    indexed_valid, val_errors = validate_smart_payloads_indexed(all_norm)
    preview = format_preview_table(all_norm, val_errors)
    print(preview)

    if val_errors:
        print(
            f"\n{len(val_errors)} validation issue(s); fix CSVs or rows before import.",
            file=sys.stderr,
        )
        return 1

    if not args.apply:
        print("\nOK (preview only). Use --apply to POST and archive.", file=sys.stderr)
        return 0

    dry_run = bool(args.import_dry_run)
    import_payloads = [p for _, p in indexed_valid]
    imp = import_smart_payloads(
        import_payloads,
        base_url=args.base_url,
        bearer_token=args.token,
        dry_run=dry_run,
    )

    if imp.failed:
        for f in imp.failed:
            print(
                f"import failed [batch {f.payload_index}]: {f.error}",
                file=sys.stderr,
            )
        return 1

    print(
        f"\nImported {len(imp.inserted)} transaction(s)"
        + (" (dry-run)" if dry_run else "")
        + ".",
        file=sys.stderr,
    )

    if args.no_archive:
        return 0

    try:
        processed_root.mkdir(parents=True, exist_ok=True)
        entries = [
            SourceArchiveEntry(
                source_path=path,
                format_name=f"{fmt}_csv",
                payloads=all_norm[start:end],
                record_ids=_record_ids_for_file_span(
                    start,
                    end,
                    indexed_valid,
                    imp,
                ),
            )
            for path, fmt, start, end in file_spans
        ]
        archive_path = write_archive(
            processed_root,
            entries,
            timestamp=datetime.now(timezone.utc),
        )
        print(f"Archive: {archive_path}", file=sys.stderr)
    except ArchiveError as exc:
        print(f"archive: {exc}", file=sys.stderr)
        return 1

    return 0


def run() -> None:
    """Setuptools / ``vaulttracker-scan`` entry (propagates exit status)."""
    raise SystemExit(main())


if __name__ == "__main__":
    run()
