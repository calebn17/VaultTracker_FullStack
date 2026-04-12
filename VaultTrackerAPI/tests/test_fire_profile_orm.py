"""ORM persistence tests for FIREProfile (no HTTP)."""

from sqlalchemy.orm import Session

from app.models.fire_profile import FIREProfile
from app.models.user import User


def test_fire_profile_round_trip_persist_and_query_by_user_id(
    db_session: Session,
) -> None:
    # Saving a profile and loading it again by user_id returns the same fields
    # and timestamps.
    user = User(firebase_id="fire-orm-test-user")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    profile = FIREProfile(
        user_id=user.id,
        current_age=32,
        annual_income=145_000.0,
        annual_expenses=62_000.0,
        target_retirement_age=45,
    )
    db_session.add(profile)
    db_session.commit()
    db_session.refresh(profile)

    assert profile.id
    assert profile.created_at is not None
    assert profile.updated_at is not None

    loaded = db_session.query(FIREProfile).filter(FIREProfile.user_id == user.id).one()
    assert loaded.id == profile.id
    assert loaded.current_age == 32
    assert loaded.annual_income == 145_000.0
    assert loaded.annual_expenses == 62_000.0
    assert loaded.target_retirement_age == 45


def test_fire_profile_optional_target_age_null(db_session: Session) -> None:
    # A profile without a target retirement age stores and reloads with null for
    # that column.
    user = User(firebase_id="fire-orm-null-target")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    profile = FIREProfile(
        user_id=user.id,
        current_age=40,
        annual_income=100_000.0,
        annual_expenses=50_000.0,
        target_retirement_age=None,
    )
    db_session.add(profile)
    db_session.commit()

    loaded = db_session.query(FIREProfile).filter(FIREProfile.user_id == user.id).one()
    assert loaded.target_retirement_age is None


def test_user_fire_profile_relationship(db_session: Session) -> None:
    # After commit, the User ORM object exposes the linked FIRE profile through
    # fire_profile.
    user = User(firebase_id="fire-orm-rel")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    profile = FIREProfile(
        user_id=user.id,
        current_age=28,
        annual_income=80_000.0,
        annual_expenses=40_000.0,
    )
    db_session.add(profile)
    db_session.commit()

    db_session.refresh(user)
    assert user.fire_profile is not None
    assert user.fire_profile.current_age == 28
    assert user.fire_profile.user_id == user.id
