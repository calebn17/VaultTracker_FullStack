"""End-to-end CLI tests (inbox → preview / apply + archive)."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from vaulttracker_scanner.archive import read_manifest
from vaulttracker_scanner.cli import main
from vaulttracker_scanner.import_payloads import ImportBatchResult
from vaulttracker_scanner.models import ImportFailed, ImportInserted

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _copy_coinbase_inbox(tmp_path: Path) -> Path:
    root = tmp_path
    inbox = root / "inbox"
    inbox.mkdir(parents=True)
    shutil.copy(FIXTURES / "coinbase_sample.csv", inbox / "coinbase_sample.csv")
    return root


def test_cli_preview_only_ok(tmp_path, capsys) -> None:
    root = _copy_coinbase_inbox(tmp_path)
    code = main(["--root", str(root)])
    assert code == 0
    captured = capsys.readouterr()
    assert "BTC" in captured.out
    assert "preview only" in captured.err.lower()


def test_cli_parse_error(tmp_path) -> None:
    root = tmp_path
    inbox = root / "inbox"
    inbox.mkdir(parents=True)
    (inbox / "x.csv").write_text("a,b\nc,d\n", encoding="utf-8")
    code = main(["--root", str(root)])
    assert code == 1


def test_cli_apply_archives_with_mocked_import(tmp_path, monkeypatch) -> None:
    root = _copy_coinbase_inbox(tmp_path)
    captured: dict[str, object] = {}

    def fake_import(payloads, **kwargs):
        captured["n"] = len(payloads)
        captured["dry_run"] = kwargs.get("dry_run")
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=i,
                    id=f"uuid-{i}",
                    asset=p["asset_name"],
                    account=p["account_name"],
                )
                for i, p in enumerate(payloads)
            ],
            failed=[],
        )

    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(["--root", str(root), "--apply"])
    assert code == 0
    assert captured["n"] == 2
    assert captured["dry_run"] is False

    proc = root / "processed"
    dirs = sorted(d for d in proc.iterdir() if d.is_dir())
    assert len(dirs) == 1
    manifest = read_manifest(dirs[0])
    assert len(manifest.files) == 1
    assert manifest.files[0].transactions_inserted == 2
    assert len(manifest.files[0].record_ids) == 2


def test_cli_apply_import_dry_run_flag(tmp_path, monkeypatch) -> None:
    root = _copy_coinbase_inbox(tmp_path)
    captured: dict[str, bool] = {}

    def fake_import(payloads, **kwargs):
        captured["dry_run"] = bool(kwargs.get("dry_run"))
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=i,
                    id=f"d{i}",
                    asset=p["asset_name"],
                    account=p["account_name"],
                )
                for i, p in enumerate(payloads)
            ],
            failed=[],
        )

    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(["--root", str(root), "--apply", "--import-dry-run"])
    assert code == 0
    assert captured.get("dry_run") is True


def test_cli_apply_no_archive(tmp_path, monkeypatch) -> None:
    root = _copy_coinbase_inbox(tmp_path)

    def fake_import(payloads, **kwargs):
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=i,
                    id=f"id{i}",
                    asset=p["asset_name"],
                    account=p["account_name"],
                )
                for i, p in enumerate(payloads)
            ],
            failed=[],
        )

    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(["--root", str(root), "--apply", "--no-archive"])
    assert code == 0
    proc = root / "processed"
    assert not proc.exists()


def test_cli_apply_partial_failure_still_archives(tmp_path, monkeypatch) -> None:
    root = _copy_coinbase_inbox(tmp_path)

    def fake_import(payloads, **kwargs):
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=0,
                    id="ok-0",
                    asset=payloads[0]["asset_name"],
                    account=payloads[0]["account_name"],
                )
            ],
            failed=[ImportFailed(payload_index=1, error="HTTP 422: bad row")],
        )

    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(["--root", str(root), "--apply"])
    assert code == 1

    proc = root / "processed"
    dirs = sorted(d for d in proc.iterdir() if d.is_dir())
    assert len(dirs) == 1
    manifest = read_manifest(dirs[0])
    assert len(manifest.files) == 1
    assert manifest.files[0].transactions_inserted == 1
    assert manifest.files[0].record_ids == ["ok-0"]


def test_cli_apply_uses_env_token_when_flag_missing(tmp_path, monkeypatch) -> None:
    root = _copy_coinbase_inbox(tmp_path)
    captured: dict[str, object] = {}

    def fake_import(payloads, **kwargs):
        captured["token"] = kwargs.get("bearer_token")
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=i,
                    id=f"id-{i}",
                    asset=p["asset_name"],
                    account=p["account_name"],
                )
                for i, p in enumerate(payloads)
            ],
            failed=[],
        )

    monkeypatch.setenv("VT_SCANNER_TOKEN", "env-token-123")
    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(["--root", str(root), "--apply"])
    assert code == 0
    assert captured["token"] == "env-token-123"


def test_cli_apply_with_vision_json_only(tmp_path, monkeypatch) -> None:
    root = tmp_path
    inbox = root / "inbox"
    inbox.mkdir(parents=True)
    vision_json = root / "vision_extract.json"
    vision_json.write_text(
        json.dumps(
            [
                {
                    "asset_name": "Ethereum",
                    "symbol": "ETH",
                    "category": "crypto",
                    "quantity": 1.25,
                    "price_per_unit": 2500,
                    "transaction_type": "buy",
                    "account_name": "Coinbase",
                    "account_type": "cryptoExchange",
                    "date": "2024-03-01",
                }
            ]
        ),
        encoding="utf-8",
    )
    captured: dict[str, object] = {}

    def fake_import(payloads, **kwargs):
        captured["n"] = len(payloads)
        return ImportBatchResult(
            inserted=[
                ImportInserted(
                    payload_index=0,
                    id="vision-0",
                    asset=payloads[0]["asset_name"],
                    account=payloads[0]["account_name"],
                )
            ],
            failed=[],
        )

    monkeypatch.setattr("vaulttracker_scanner.cli.import_smart_payloads", fake_import)
    code = main(
        [
            "--root",
            str(root),
            "--apply",
            "--vision-json",
            str(vision_json),
        ]
    )
    assert code == 0
    assert captured["n"] == 1

    proc = root / "processed"
    dirs = sorted(d for d in proc.iterdir() if d.is_dir())
    assert len(dirs) == 1
    manifest = read_manifest(dirs[0])
    assert len(manifest.files) == 1
    assert manifest.files[0].format == "vision_json"
