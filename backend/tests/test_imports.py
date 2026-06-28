from app.core.config import settings
from app.schemas.scan import GameCandidate
from app.services import igdb
from app.services.importers import base as importers_base
from app.services.importers import steam as steam_mod
from app.services.importers.base import OwnedGame


def _stub_igdb(monkeypatch, mapping=None):
    """Make IGDB matching deterministic and offline."""
    mapping = mapping or {}

    def fake_search(q, limit=10):
        cand = mapping.get(q)
        return [cand] if cand else []

    monkeypatch.setattr(igdb, "search_games", fake_search)


def test_steam_import_not_configured(auth_client, monkeypatch):
    monkeypatch.setattr(settings, "steam_api_key", None)
    r = auth_client.post("/imports/steam", json={"steam_id": "76561197960434622"})
    assert r.status_code == 503


def test_steam_import_success_and_dedup(auth_client, monkeypatch):
    monkeypatch.setattr(settings, "steam_api_key", "fake-key")
    _stub_igdb(
        monkeypatch,
        {"Portal 2": GameCandidate(title="Portal 2", igdb_id=7346, source="igdb",
                                   cover_url="http://img/p2.jpg")},
    )

    def fake_fetch(self):
        return [
            OwnedGame(title="Portal 2", store_app_id="620", platform_name="PC"),
            OwnedGame(title="Unknown Indie", store_app_id="999", platform_name="PC"),
        ]

    monkeypatch.setattr(steam_mod.SteamImporter, "fetch_owned", fake_fetch)

    r = auth_client.post("/imports/steam", json={"steam_id": "76561197960434622"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["fetched"] == 2
    assert body["created"] == 2
    assert body["skipped_duplicates"] == 0
    assert "Unknown Indie" in body["unmatched"]  # no IGDB match

    # The matched item carries IGDB metadata.
    items = auth_client.get("/items", params={"source": "steam"}).json()
    portal = next(it for it in items["items"] if it["title"] == "Portal 2")
    assert portal["igdb_id"] == 7346
    assert portal["format"] == "digital"

    # Re-import skips everything (dedup by store_app_id).
    r2 = auth_client.post("/imports/steam", json={"steam_id": "76561197960434622"})
    assert r2.json()["created"] == 0
    assert r2.json()["skipped_duplicates"] == 2

    # Connection saved + listed.
    conns = auth_client.get("/imports/connections").json()
    assert any(c["provider"] == "steam" for c in conns)


def test_csv_import(auth_client, monkeypatch):
    _stub_igdb(monkeypatch, {"The Witcher 3": GameCandidate(title="The Witcher 3", igdb_id=1942,
                                                            source="igdb")})
    csv_text = "Game,Store\nThe Witcher 3,GOG\nCyberpunk 2077,GOG\n"
    r = auth_client.post(
        "/imports/csv",
        json={
            "csv_text": csv_text,
            "mapping": {"title": "Game", "platform": "Store"},
            "source": "gog",
            "default_format": "digital",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["provider"] == "gog"
    assert body["fetched"] == 2
    assert body["created"] == 2
    assert "Cyberpunk 2077" in body["unmatched"]


def test_csv_bad_mapping(auth_client, monkeypatch):
    _stub_igdb(monkeypatch)
    r = auth_client.post(
        "/imports/csv",
        json={"csv_text": "A,B\n1,2\n", "mapping": {"title": "NotThere"}},
    )
    assert r.status_code == 422


def test_persist_dedup_by_title_without_appid(auth_client, monkeypatch):
    """Connector rows lacking a store_app_id dedup by title."""
    _stub_igdb(monkeypatch)
    # Direct unit-ish check via CSV (no app id column).
    csv_text = "Game\nTetris\nTetris\n"
    r = auth_client.post(
        "/imports/csv",
        json={"csv_text": csv_text, "mapping": {"title": "Game"}, "source": "csv"},
    )
    body = r.json()
    assert body["created"] == 1
    assert body["skipped_duplicates"] == 1
