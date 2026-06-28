"""Test fixtures: file-backed SQLite (shared with the app engine), authed client."""
import os
import tempfile

import pytest
from fastapi.testclient import TestClient

# Configure a throwaway environment BEFORE importing the app, so app.core.db
# builds its engine against this SQLite file. Tests then reuse that same engine,
# which means the app's startup seeding hits the same database.
_tmp = tempfile.mkdtemp(prefix="yagl-test-")
os.environ["SECRET_KEY"] = "test-secret-key-that-is-at-least-32-bytes-long"
os.environ["DATABASE_URL"] = f"sqlite+pysqlite:///{_tmp}/test.db"
os.environ["MEDIA_ROOT"] = os.path.join(_tmp, "media")

from app.core.db import engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Base  # noqa: E402


@pytest.fixture(autouse=True)
def _schema():
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture
def client():
    with TestClient(app) as c:  # triggers startup (mount media, seed platforms)
        yield c


@pytest.fixture
def auth_client(client):
    """A TestClient carrying an Authorization header for a registered user."""
    resp = client.post(
        "/auth/register", json={"email": "owner@example.com", "password": "supersecret"}
    )
    assert resp.status_code == 201, resp.text
    token = resp.json()["access_token"]
    client.headers.update({"Authorization": f"Bearer {token}"})
    return client
