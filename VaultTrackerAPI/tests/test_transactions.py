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
