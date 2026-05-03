"""Tests for discover_manifest."""

from __future__ import annotations

import pytest

from vaulttracker_scanner.discover import DiscoverError, discover_manifest


def test_discover_groups_files(tmp_path) -> None:
    (tmp_path / "a.csv").write_text("x")
    (tmp_path / "b.PDF").write_bytes(b"%PDF-1.4")
    (tmp_path / "c.PNG").write_bytes(b"\x89PNG\r\n\x1a\n")
    (tmp_path / "d.JPEG").write_bytes(b"")
    (tmp_path / "e.heic").write_bytes(b"")
    (tmp_path / "readme.txt").write_text("nope")

    m = discover_manifest(tmp_path)
    assert m["csv"] == ["a.csv"]
    assert m["pdf"] == ["b.PDF"]
    assert m["image"] == ["c.PNG", "d.JPEG", "e.heic"]


def test_discover_empty_directory_raises(tmp_path) -> None:
    with pytest.raises(DiscoverError, match="no supported files"):
        discover_manifest(tmp_path)


def test_discover_only_unsupported_raises(tmp_path) -> None:
    (tmp_path / "readme.txt").write_text("x")
    with pytest.raises(DiscoverError, match="no supported files"):
        discover_manifest(tmp_path)


def test_discover_not_a_directory_raises(tmp_path) -> None:
    f = tmp_path / "file.txt"
    f.write_text("x")
    with pytest.raises(DiscoverError, match="not a directory"):
        discover_manifest(f)


def test_discover_non_recursive(tmp_path) -> None:
    sub = tmp_path / "nested"
    sub.mkdir()
    (sub / "inside.csv").write_text("h\n")
    (tmp_path / "top.pdf").write_text("x")

    m = discover_manifest(tmp_path)
    assert m["csv"] == []
    assert m["pdf"] == ["top.pdf"]
