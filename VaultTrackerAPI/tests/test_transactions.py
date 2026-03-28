import uuid

from app.models.transaction import Transaction


def test_delete_last_smart_transaction_removes_asset_from_dashboard(client, test_user, db_session):
    """Deleting the only tx for an asset removes the holding (row deleted + dashboard omits empties)."""
    body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Solana",
        "symbol": "SOL",
        "quantity": 1.0,
        "price_per_unit": 100.0,
        "account_name": "DelTest",
        "account_type": "cryptoExchange",
    }
    r0 = client.post("/api/v1/transactions/smart", json=body)
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]

    d1 = client.get("/api/v1/dashboard")
    assert d1.status_code == 200
    names = sorted(
        h["name"]
        for cat in d1.json()["groupedHoldings"].values()
        for h in cat
    )
    assert "Solana" in names

    r_del = client.delete(f"/api/v1/transactions/{tx_id}")
    assert r_del.status_code == 204

    d2 = client.get("/api/v1/dashboard")
    assert d2.status_code == 200
    names_after = [
        h["name"]
        for cat in d2.json()["groupedHoldings"].values()
        for h in cat
    ]
    assert "Solana" not in names_after


def test_smart_transactions_with_different_dates_yield_multiple_networth_points(
    client, test_user, db_session
):
    """Net worth snapshots use each trade's date so history matches transaction dates."""
    base_buy = {
        "transaction_type": "buy",
        "category": "crypto",
        "quantity": 0.1,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    r1 = client.post(
        "/api/v1/transactions/smart",
        json={
            **base_buy,
            "asset_name": "Bitcoin",
            "symbol": "BTC",
            "date": "2024-02-01T12:00:00Z",
        },
    )
    assert r1.status_code == 201, r1.text
    r2 = client.post(
        "/api/v1/transactions/smart",
        json={
            **base_buy,
            "asset_name": "Ethereum",
            "symbol": "ETH",
            "date": "2024-03-15T12:00:00Z",
        },
    )
    assert r2.status_code == 201, r2.text

    h = client.get("/api/v1/networth/history", params={"period": "daily"})
    assert h.status_code == 200
    snaps = h.json()["snapshots"]
    assert len(snaps) == 2


def test_deleting_backdated_transaction_adjusts_historical_snapshots(client, test_user, db_session):
    """Deleting a backdated buy corrects all snapshot values on or after that date."""
    base = {
        "transaction_type": "buy",
        "category": "crypto",
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    # Two buys on different dates
    r1 = client.post("/api/v1/transactions/smart", json={
        **base, "asset_name": "Bitcoin", "symbol": "BTC",
        "quantity": 1.0, "price_per_unit": 40000.0,
        "date": "2024-01-01T00:00:00Z",
    })
    assert r1.status_code == 201, r1.text
    btc_tx_id = r1.json()["id"]

    r2 = client.post("/api/v1/transactions/smart", json={
        **base, "asset_name": "Ethereum", "symbol": "ETH",
        "quantity": 1.0, "price_per_unit": 5000.0,
        "date": "2024-06-01T00:00:00Z",
    })
    assert r2.status_code == 201, r2.text

    h_before = client.get("/api/v1/networth/history", params={"period": "daily"})
    snaps_before = h_before.json()["snapshots"]
    # Jan snapshot = 40000, Jun snapshot = 45000
    assert len(snaps_before) == 2
    jan_value = snaps_before[0]["value"]
    jun_value = snaps_before[1]["value"]
    assert jan_value == 40000.0
    assert jun_value == 45000.0

    # Delete the January BTC buy (backdated)
    r_del = client.delete(f"/api/v1/transactions/{btc_tx_id}")
    assert r_del.status_code == 204

    h_after = client.get("/api/v1/networth/history", params={"period": "daily"})
    snaps_after = h_after.json()["snapshots"]

    # Jan snapshot should decrease by 40000
    jan_after = next(s for s in snaps_after if "2024-01" in s["date"])
    assert jan_after["value"] == 0.0  # clamped to 0 (was 40000 - 40000)

    # Jun snapshot should also decrease by 40000 (the delta propagates forward)
    jun_after = next(s for s in snaps_after if "2024-06" in s["date"])
    assert jun_after["value"] == 5000.0  # was 45000 - 40000


def test_smart_transaction_creates_account_asset_and_transaction(client, test_user, db_session):
    body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 0.5,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    r = client.post("/api/v1/transactions/smart", json=body)
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["transaction_type"] == "buy"
    assert data["quantity"] == 0.5
    assert data["user_id"] == test_user.id

    lst = client.get("/api/v1/transactions")
    assert lst.status_code == 200
    rows = lst.json()
    assert len(rows) == 1
    row = rows[0]
    assert row["total_value"] == 0.5 * 40000.0
    assert row["asset"]["symbol"] == "BTC"
    assert row["asset"]["name"] == "Bitcoin"
    assert row["account"]["name"] == "Coinbase"
    assert row["account"]["account_type"] == "cryptoExchange"


def test_legacy_create_transaction_still_works(client, test_user, db_session):
    from app.models.account import Account
    from app.models.asset import Asset

    acct = Account(
        user_id=test_user.id,
        name="Bank",
        account_type="bank",
    )
    ast = Asset(
        user_id=test_user.id,
        name="Cash",
        symbol=None,
        category="cash",
        quantity=0.0,
        current_value=0.0,
    )
    db_session.add_all([acct, ast])
    db_session.commit()
    db_session.refresh(acct)
    db_session.refresh(ast)

    r = client.post(
        "/api/v1/transactions",
        json={
            "asset_id": ast.id,
            "account_id": acct.id,
            "transaction_type": "buy",
            "quantity": 100.0,
            "price_per_unit": 1.0,
        },
    )
    assert r.status_code == 201, r.text


def test_legacy_update_409_when_linked_asset_missing(client, test_user, db_session):
    from app.models.account import Account
    from app.models.asset import Asset

    acct = Account(
        user_id=test_user.id,
        name="Bank",
        account_type="bank",
    )
    ast = Asset(
        user_id=test_user.id,
        name="Cash",
        symbol=None,
        category="cash",
        quantity=0.0,
        current_value=0.0,
    )
    db_session.add_all([acct, ast])
    db_session.commit()
    db_session.refresh(acct)
    db_session.refresh(ast)

    r0 = client.post(
        "/api/v1/transactions",
        json={
            "asset_id": ast.id,
            "account_id": acct.id,
            "transaction_type": "buy",
            "quantity": 10.0,
            "price_per_unit": 1.0,
        },
    )
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]

    tx_row = db_session.query(Transaction).filter(Transaction.id == tx_id).first()
    assert tx_row is not None
    tx_row.asset_id = str(uuid.uuid4())
    db_session.commit()

    r1 = client.put(
        f"/api/v1/transactions/{tx_id}",
        json={"quantity": 5.0},
    )
    assert r1.status_code == 409


def test_smart_transaction_update_changes_quantity_and_preserves_resolution(client, test_user, db_session):
    create_body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 1.0,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    r0 = client.post("/api/v1/transactions/smart", json=create_body)
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]

    update_body = {
        **create_body,
        "quantity": 2.0,
        "price_per_unit": 41000.0,
    }
    r1 = client.put(f"/api/v1/transactions/{tx_id}/smart", json=update_body)
    assert r1.status_code == 200, r1.text
    assert r1.json()["quantity"] == 2.0
    assert r1.json()["price_per_unit"] == 41000.0

    lst = client.get("/api/v1/transactions")
    assert lst.status_code == 200
    rows = lst.json()
    assert len(rows) == 1
    assert rows[0]["quantity"] == 2.0
    assert rows[0]["total_value"] == 2.0 * 41000.0


def test_smart_transaction_update_409_when_linked_asset_missing(client, test_user, db_session):
    create_body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 1.0,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    r0 = client.post("/api/v1/transactions/smart", json=create_body)
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]

    tx_row = db_session.query(Transaction).filter(Transaction.id == tx_id).first()
    assert tx_row is not None
    tx_row.asset_id = str(uuid.uuid4())
    db_session.commit()

    r1 = client.put(
        f"/api/v1/transactions/{tx_id}/smart",
        json={**create_body, "quantity": 2.0},
    )
    assert r1.status_code == 409


def test_smart_transaction_update_404(client, test_user, db_session):
    r = client.put(
        "/api/v1/transactions/nonexistent-id/smart",
        json={
            "transaction_type": "buy",
            "category": "crypto",
            "asset_name": "X",
            "symbol": "BTC",
            "quantity": 1.0,
            "price_per_unit": 1.0,
            "account_name": "A",
            "account_type": "cryptoExchange",
        },
    )
    assert r.status_code == 404


def test_smart_transaction_update_moves_to_new_asset_and_account(client, test_user, db_session):
    """Reversal applies to old asset; new payload resolves a different account + symbol."""
    create_body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 1.0,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    r0 = client.post("/api/v1/transactions/smart", json=create_body)
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]

    update_body = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Ethereum",
        "symbol": "ETH",
        "quantity": 2.0,
        "price_per_unit": 3000.0,
        "account_name": "Kraken",
        "account_type": "cryptoExchange",
    }
    r1 = client.put(f"/api/v1/transactions/{tx_id}/smart", json=update_body)
    assert r1.status_code == 200, r1.text

    lst = client.get("/api/v1/transactions")
    assert lst.status_code == 200
    rows = lst.json()
    assert len(rows) == 1
    assert rows[0]["asset"]["symbol"] == "ETH"
    assert rows[0]["asset"]["name"] == "Ethereum"
    assert rows[0]["account"]["name"] == "Kraken"
    assert rows[0]["total_value"] == 2.0 * 3000.0

    assets_r = client.get("/api/v1/assets")
    assert assets_r.status_code == 200
    by_symbol = {a["symbol"]: a for a in assets_r.json() if a.get("symbol")}
    assert by_symbol["BTC"]["quantity"] == 0.0
    assert by_symbol["ETH"]["quantity"] == 2.0
    assert by_symbol["ETH"]["current_value"] == 2.0 * 3000.0
