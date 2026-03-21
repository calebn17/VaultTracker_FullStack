from app.services.cache_service import cache


def test_analytics_returns_allocation_and_performance(client, test_user, db_session):
    r = client.get("/api/v1/analytics")
    assert r.status_code == 200
    body = r.json()
    assert "allocation" in body
    assert "performance" in body
    for cat in ("crypto", "stocks", "cash", "realEstate", "retirement"):
        assert cat in body["allocation"]
        assert "value" in body["allocation"][cat]
        assert "percentage" in body["allocation"][cat]


def test_dashboard_populates_cache_and_invalidates_on_transaction(client, test_user, db_session):
    key = f"dashboard:{test_user.id}"
    assert cache.get(key) is None

    r1 = client.get("/api/v1/dashboard")
    assert r1.status_code == 200
    assert cache.get(key) is not None

    # Smart write mutates holdings → cache cleared for user
    client.post(
        "/api/v1/transactions/smart",
        json={
            "transaction_type": "buy",
            "category": "crypto",
            "asset_name": "Bitcoin",
            "symbol": "BTC",
            "quantity": 1.0,
            "price_per_unit": 10.0,
            "account_name": "Ex",
            "account_type": "cryptoExchange",
        },
    )
    assert cache.get(key) is None

    r2 = client.get("/api/v1/dashboard")
    assert r2.status_code == 200
    assert r2.json()["totalNetWorth"] != 0.0
    assert cache.get(key) is not None
