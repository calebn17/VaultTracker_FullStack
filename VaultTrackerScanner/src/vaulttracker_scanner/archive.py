"""Archive imported sources + JSON payloads under ``processed/<timestamp>/``."""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from vaulttracker_scanner.models import ArchiveManifest, ArchiveManifestEntry


@dataclass(frozen=True)
class SourceArchiveEntry:
    """One source file and the smart payloads / record ids produced from it."""

    source_path: Path
    format_name: str
    payloads: list[dict[str, Any]]
    record_ids: list[str]


class ArchiveError(ValueError):
    """Invalid paths, missing files, or corrupt archive layout."""


def archive_folder_name(when: datetime | None = None) -> str:
    """Filesystem segment ``YYYY-MM-DDTHH-MM-SS`` (UTC, no ``:`` in time)."""
    dt = (when or datetime.now(timezone.utc)).astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H-%M-%S")


def _allocate_unique_basename(used: set[str], original: str) -> str:
    if original not in used:
        used.add(original)
        return original
    path = Path(original)
    stem, suffix = path.stem, path.suffix
    for i in range(1, 10_000):
        candidate = f"{stem}_{i}{suffix}"
        if candidate not in used:
            used.add(candidate)
            return candidate
    msg = "too many colliding source basenames"
    raise ArchiveError(msg)


def write_archive(
    processed_root: Path,
    entries: list[SourceArchiveEntry],
    *,
    timestamp: datetime | None = None,
) -> Path:
    """Create ``processed_root /<UTC timestamp>/`` layout.

    Writes ``sources/``, ``payloads/``, and ``manifest.json``.

    Payload JSON files are arrays of smart-transaction dicts (JSON-ready). Each
    ``record_ids`` length becomes ``transactions_inserted`` in the manifest.
    """
    if not entries:
        raise ArchiveError("at least one SourceArchiveEntry is required")

    when = (timestamp or datetime.now(timezone.utc)).astimezone(timezone.utc)
    folder = archive_folder_name(when)
    archive_path = Path(processed_root).expanduser().resolve() / folder
    if archive_path.exists():
        raise ArchiveError(f"archive path already exists: {archive_path}")

    sources_dir = archive_path / "sources"
    payloads_dir = archive_path / "payloads"
    sources_dir.mkdir(parents=True)
    payloads_dir.mkdir(parents=True)

    used_basenames: set[str] = set()
    manifest_files: list[ArchiveManifestEntry] = []

    for entry in entries:
        src = entry.source_path.expanduser().resolve()
        if not src.is_file():
            raise ArchiveError(f"source is not a file: {src}")

        dest_base = _allocate_unique_basename(used_basenames, src.name)
        rel_source = f"sources/{dest_base}"
        shutil.copy2(src, archive_path / rel_source)

        stem = Path(dest_base).stem
        payload_name = f"{stem}.json"
        rel_payload = f"payloads/{payload_name}"
        payload_path = archive_path / rel_payload
        payload_path.write_text(
            json.dumps(entry.payloads, indent=2, default=str, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )

        manifest_files.append(
            ArchiveManifestEntry(
                source=rel_source,
                payload=rel_payload,
                format=entry.format_name,
                transactions_inserted=len(entry.record_ids),
                record_ids=list(entry.record_ids),
            ),
        )

    manifest = ArchiveManifest(timestamp=when, files=manifest_files)
    (archive_path / "manifest.json").write_text(
        json.dumps(manifest.model_dump(mode="json"), indent=2) + "\n",
        encoding="utf-8",
    )
    return archive_path


def read_manifest(archive_dir: Path) -> ArchiveManifest:
    """Load and validate ``manifest.json`` under *archive_dir*."""
    path = Path(archive_dir).expanduser().resolve() / "manifest.json"
    if not path.is_file():
        raise ArchiveError(f"missing manifest: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    return ArchiveManifest.model_validate(data)


def load_payload_lists_from_manifest(
    archive_dir: Path,
) -> list[tuple[ArchiveManifestEntry, list[dict[str, Any]]]]:
    """For each manifest row, load the JSON array under ``payload`` (relative paths)."""
    base = Path(archive_dir).expanduser().resolve()
    manifest = read_manifest(base)
    out: list[tuple[ArchiveManifestEntry, list[dict[str, Any]]]] = []

    for finfo in manifest.files:
        payload_path = base / finfo.payload
        if not payload_path.is_file():
            raise ArchiveError(f"missing payload file: {payload_path}")
        raw: Any = json.loads(payload_path.read_text(encoding="utf-8"))
        if not isinstance(raw, list):
            raise ArchiveError(f"payload must be a JSON array: {payload_path}")
        rows: list[dict[str, Any]] = []
        for item in raw:
            if not isinstance(item, dict):
                msg = f"payload array must contain objects: {payload_path}"
                raise ArchiveError(msg)
            rows.append(dict(item))
        out.append((finfo, rows))

    return out


def load_flat_payloads_for_reimport(archive_dir: Path) -> list[dict[str, Any]]:
    """Concatenate all payload arrays in manifest order (recovery without re-parse)."""
    flat: list[dict[str, Any]] = []
    for _, rows in load_payload_lists_from_manifest(archive_dir):
        flat.extend(rows)
    return flat
