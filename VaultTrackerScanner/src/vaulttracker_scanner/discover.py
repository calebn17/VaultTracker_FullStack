"""Discover supported files under a directory (CSV, PDF, images).

Output shape matches Documentation/Plans/2026-05-02-scanner-design.md ``discover.py``.
"""

from __future__ import annotations

from pathlib import Path

# extension (lowercase) -> manifest bucket
_EXT_TO_BUCKET: dict[str, str] = {
    ".csv": "csv",
    ".pdf": "pdf",
    ".png": "image",
    ".jpg": "image",
    ".jpeg": "image",
    ".heic": "image",
}


class DiscoverError(ValueError):
    """No usable files, invalid path, or path is not a directory."""


def discover_manifest(root: Path | str) -> dict[str, list[str]]:
    """Scan *root* (non-recursive) and group supported files.

    Returns JSON-friendly paths relative to *root*, POSIX style, each list sorted.
    Keys always present: ``csv``, ``pdf``, ``image`` (possibly empty lists —
    normally an empty directory raises).

    Raises:
        DiscoverError: not a directory, missing path, or no supported files found.
    """
    base = Path(root).expanduser()
    try:
        base = base.resolve()
    except OSError as exc:
        raise DiscoverError(f"cannot resolve path: {root!r}") from exc

    if not base.is_dir():
        raise DiscoverError(f"not a directory: {base}")

    buckets: dict[str, list[str]] = {"csv": [], "pdf": [], "image": []}

    try:
        entries = list(base.iterdir())
    except OSError as exc:
        raise DiscoverError(f"cannot read directory: {base}") from exc

    for entry in entries:
        if not entry.is_file():
            continue
        bucket = _EXT_TO_BUCKET.get(entry.suffix.lower())
        if bucket is None:
            continue
        try:
            rel = entry.relative_to(base).as_posix()
        except ValueError:
            rel = entry.name
        buckets[bucket].append(rel)

    for key in buckets:
        buckets[key].sort()

    total = sum(len(v) for v in buckets.values())
    if total == 0:
        raise DiscoverError(
            f"no supported files in {base} "
            f"(expect .csv, .pdf, .png, .jpg, .jpeg, .heic)",
        )

    return buckets
