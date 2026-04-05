from datetime import datetime, timedelta, timezone

from app.models.networth_snapshot import NetWorthSnapshot


def test_networth_history_daily_groups_last_per_day(client, test_user, db_session):
    base = datetime(2024, 1, 1, 12, 0, tzinfo=timezone.utc)
    for i, val in enumerate([100.0, 110.0, 120.0]):
        db_session.add(
            NetWorthSnapshot(
                user_id=test_user.id,
                date=base + timedelta(hours=i),
                value=val,
            )
        )
    db_session.commit()

    r = client.get("/api/v1/networth/history", params={"period": "daily"})
    assert r.status_code == 200
    snaps = r.json()["snapshots"]
    assert len(snaps) == 1
    assert snaps[0]["value"] == 120.0


def test_networth_history_all_returns_each_row(client, test_user, db_session):
    t0 = datetime(2024, 1, 1, tzinfo=timezone.utc)
    db_session.add(NetWorthSnapshot(user_id=test_user.id, date=t0, value=1.0))
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=t0 + timedelta(hours=1),
            value=2.0,
        )
    )
    db_session.commit()

    r = client.get("/api/v1/networth/history", params={"period": "all"})
    assert r.status_code == 200
    assert len(r.json()["snapshots"]) == 2


def test_networth_history_weekly_keeps_last_snapshot_per_iso_week(
    client, test_user, db_session
):
    # 2024-01-01 is Monday — same ISO week as 2024-01-06 (Saturday).
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 1, 10, 0, tzinfo=timezone.utc),
            value=10.0,
        )
    )
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 3, 10, 0, tzinfo=timezone.utc),
            value=20.0,
        )
    )
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 6, 10, 0, tzinfo=timezone.utc),
            value=30.0,
        )
    )
    # Next Monday → new ISO week.
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 8, 10, 0, tzinfo=timezone.utc),
            value=40.0,
        )
    )
    db_session.commit()

    r = client.get("/api/v1/networth/history", params={"period": "weekly"})
    assert r.status_code == 200
    snaps = r.json()["snapshots"]
    assert len(snaps) == 2
    assert snaps[0]["value"] == 30.0
    assert snaps[1]["value"] == 40.0


def test_networth_history_monthly_keeps_last_snapshot_per_calendar_month(
    client, test_user, db_session
):
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 5, 12, 0, tzinfo=timezone.utc),
            value=100.0,
        )
    )
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 1, 25, 12, 0, tzinfo=timezone.utc),
            value=200.0,
        )
    )
    db_session.add(
        NetWorthSnapshot(
            user_id=test_user.id,
            date=datetime(2024, 2, 1, 12, 0, tzinfo=timezone.utc),
            value=300.0,
        )
    )
    db_session.commit()

    r = client.get("/api/v1/networth/history", params={"period": "monthly"})
    assert r.status_code == 200
    snaps = r.json()["snapshots"]
    assert len(snaps) == 2
    assert snaps[0]["value"] == 200.0
    assert snaps[1]["value"] == 300.0
