"""HTTP 422 tests for stricter Pydantic bounds (accounts, assets, transactions)."""


def _smart_base(**overrides):
    base = {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 1.0,
        "price_per_unit": 40000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
    }
    base.update(overrides)
    return base


def test_create_account_invalid_account_type_422(client):
    r = client.post(
        "/api/v1/accounts",
        json={"name": "A", "account_type": "invalid"},
    )
    assert r.status_code == 422


def test_create_account_name_too_long_422(client):
    r = client.post(
        "/api/v1/accounts",
        json={"name": "x" * 201, "account_type": "brokerage"},
    )
    assert r.status_code == 422


def test_create_asset_invalid_category_422(client):
    r = client.post(
        "/api/v1/assets",
        json={
            "name": "X",
            "symbol": "BTC",
            "category": "stonks",
            "quantity": 1.0,
            "current_value": 1.0,
        },
    )
    assert r.status_code == 422


def test_create_asset_negative_quantity_422(client):
    r = client.post(
        "/api/v1/assets",
        json={
            "name": "X",
            "category": "cash",
            "quantity": -1.0,
            "current_value": 0.0,
        },
    )
    assert r.status_code == 422


def test_smart_transaction_zero_quantity_422(client):
    r = client.post(
        "/api/v1/transactions/smart",
        json=_smart_base(quantity=0),
    )
    assert r.status_code == 422


def test_smart_transaction_zero_price_per_unit_422(client):
    r = client.post(
        "/api/v1/transactions/smart",
        json=_smart_base(price_per_unit=0),
    )
    assert r.status_code == 422


def test_smart_transaction_invalid_account_type_422(client):
    r = client.post(
        "/api/v1/transactions/smart",
        json=_smart_base(account_type="invalid"),
    )
    assert r.status_code == 422


def test_smart_transaction_asset_name_too_long_422(client):
    r = client.post(
        "/api/v1/transactions/smart",
        json=_smart_base(asset_name="x" * 201),
    )
    assert r.status_code == 422


def test_smart_transaction_symbol_required_for_crypto_422(client):
    r = client.post(
        "/api/v1/transactions/smart",
        json=_smart_base(symbol=""),
    )
    assert r.status_code == 422


def test_transaction_update_rejects_non_positive_quantity(client):
    r0 = client.post("/api/v1/transactions/smart", json=_smart_base())
    assert r0.status_code == 201, r0.text
    tx_id = r0.json()["id"]
    r_up = client.put(
        f"/api/v1/transactions/{tx_id}",
        json={"quantity": 0.0},
    )
    assert r_up.status_code == 422


def test_create_legacy_transaction_invalid_transaction_type_422(client):
    acct = client.post(
        "/api/v1/accounts",
        json={"name": "A", "account_type": "brokerage"},
    )
    assert acct.status_code == 201
    aid = acct.json()["id"]
    ast = client.post(
        "/api/v1/assets",
        json={
            "name": "IBM",
            "symbol": "IBM",
            "category": "stocks",
            "quantity": 10.0,
            "current_value": 1000.0,
        },
    )
    assert ast.status_code == 201
    asid = ast.json()["id"]
    r = client.post(
        "/api/v1/transactions",
        json={
            "asset_id": asid,
            "account_id": aid,
            "transaction_type": "hold",
            "quantity": 1.0,
            "price_per_unit": 1.0,
        },
    )
    assert r.status_code == 422


def test_create_legacy_transaction_non_positive_quantity_422(client):
    acct = client.post(
        "/api/v1/accounts",
        json={"name": "B", "account_type": "brokerage"},
    )
    assert acct.status_code == 201
    aid = acct.json()["id"]
    ast = client.post(
        "/api/v1/assets",
        json={
            "name": "IBM",
            "symbol": "IBM",
            "category": "stocks",
            "quantity": 10.0,
            "current_value": 1000.0,
        },
    )
    assert ast.status_code == 201
    asid = ast.json()["id"]
    r = client.post(
        "/api/v1/transactions",
        json={
            "asset_id": asid,
            "account_id": aid,
            "transaction_type": "buy",
            "quantity": 0.0,
            "price_per_unit": 1.0,
        },
    )
    assert r.status_code == 422
