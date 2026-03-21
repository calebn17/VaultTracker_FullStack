import pytest

from app.models.account import Account
from app.models.asset import Asset


@pytest.fixture
def mock_price_apis(monkeypatch):
    async def fake_crypto(self, symbol: str, *, use_cache: bool = True):
        return 99.0 if symbol.upper() == "BTC" else None

    async def fake_stock(self, symbol: str, *, use_cache: bool = True):
        return 55.0 if symbol.upper() == "IBM" else None

    monkeypatch.setattr(
        "app.services.price_service.PriceService.get_crypto_price",
        fake_crypto,
    )
    monkeypatch.setattr(
        "app.services.price_service.PriceService.get_stock_price",
        fake_stock,
    )


def test_get_price_tries_crypto_then_stock(client, mock_price_apis):
    r = client.get("/api/v1/prices/BTC")
    assert r.status_code == 200
    assert r.json() == {"symbol": "BTC", "price": 99.0, "source": "coingecko"}

    r2 = client.get("/api/v1/prices/IBM")
    assert r2.status_code == 200
    assert r2.json()["source"] == "alphavantage"
    assert r2.json()["price"] == 55.0


def test_refresh_prices_updates_crypto_holding(client, test_user, db_session, mock_price_apis):
    acct = Account(user_id=test_user.id, name="Ex", account_type="cryptoExchange")
    ast = Asset(
        user_id=test_user.id,
        name="Bitcoin",
        symbol="BTC",
        category="crypto",
        quantity=2.0,
        current_value=0.0,
    )
    db_session.add_all([acct, ast])
    db_session.commit()

    r = client.post("/api/v1/prices/refresh")
    assert r.status_code == 200
    payload = r.json()
    assert len(payload["updated"]) == 1
    assert payload["updated"][0]["new_value"] == 2.0 * 99.0

    db_session.refresh(ast)
    assert ast.current_value == 2.0 * 99.0
