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
