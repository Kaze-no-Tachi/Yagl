from app.schemas.scan import GameCandidate
from app.services import barcode


def test_scan_returns_candidates(auth_client, monkeypatch):
    def fake_resolve(code):
        return [
            GameCandidate(title="Super Mario Odyssey", igdb_id=26758, source="gameupc",
                          confidence=0.85, platform_name="Nintendo Switch")
        ]

    monkeypatch.setattr(barcode, "resolve_barcode", fake_resolve)
    r = auth_client.post("/scan", json={"barcode": "045496590741"})
    assert r.status_code == 200
    body = r.json()
    assert body["barcode"] == "045496590741"
    assert body["candidates"][0]["title"] == "Super Mario Odyssey"


def test_scan_empty_is_ok(auth_client, monkeypatch):
    monkeypatch.setattr(barcode, "resolve_barcode", lambda code: [])
    r = auth_client.post("/scan", json={"barcode": "0000"})
    assert r.status_code == 200
    assert r.json()["candidates"] == []


def test_scan_requires_auth(client):
    assert client.post("/scan", json={"barcode": "123"}).status_code == 401


def test_metadata_search(auth_client, monkeypatch):
    from app.services import igdb

    monkeypatch.setattr(
        igdb, "search_games",
        lambda q, limit=10: [GameCandidate(title=f"Result for {q}", source="igdb")],
    )
    r = auth_client.get("/metadata/search", params={"q": "chrono trigger"})
    assert r.status_code == 200
    assert r.json()["candidates"][0]["title"] == "Result for chrono trigger"
