"""Smoke tests for package layout."""

import vaulttracker_scanner


def test_package_version() -> None:
    assert vaulttracker_scanner.__version__ == "0.1.0"
