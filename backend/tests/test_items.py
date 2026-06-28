def _create(auth_client, **overrides):
    payload = {"title": "Halo Infinite", "kind": "game", "format": "physical"}
    payload.update(overrides)
    r = auth_client.post("/items", json=payload)
    assert r.status_code == 201, r.text
    return r.json()


def test_item_crud_and_isolation(auth_client):
    item = _create(auth_client, title="Zelda: TOTK", platform_id=10, condition="cib")
    item_id = item["id"]
    assert item["title"] == "Zelda: TOTK"
    assert item["source"] == "manual"

    # Read.
    got = auth_client.get(f"/items/{item_id}")
    assert got.status_code == 200
    assert got.json()["condition"] == "cib"

    # Update (partial).
    upd = auth_client.patch(f"/items/{item_id}", json={"condition": "loose", "price_paid": "39.99"})
    assert upd.status_code == 200
    assert upd.json()["condition"] == "loose"

    # A different user (independent client) cannot see it.
    from fastapi.testclient import TestClient

    from app.main import app

    with TestClient(app) as other:
        tok = other.post(
            "/auth/register", json={"email": "other@x.com", "password": "password123"}
        ).json()["access_token"]
        other.headers.update({"Authorization": f"Bearer {tok}"})
        assert other.get(f"/items/{item_id}").status_code == 404

    # Delete.
    assert auth_client.delete(f"/items/{item_id}").status_code == 204
    assert auth_client.get(f"/items/{item_id}").status_code == 404


def test_listing_filters(auth_client):
    _create(auth_client, title="Forza", kind="game", format="digital")
    _create(auth_client, title="Xbox Controller", kind="accessory", format="physical")
    _create(auth_client, title="PS5 Console", kind="hardware", format="physical")

    all_items = auth_client.get("/items").json()
    assert all_items["total"] == 3

    games = auth_client.get("/items", params={"kind": "game"}).json()
    assert games["total"] == 1 and games["items"][0]["title"] == "Forza"

    hardware = auth_client.get("/items", params={"kind": "hardware"}).json()
    assert hardware["total"] == 1

    search = auth_client.get("/items", params={"q": "controller"}).json()
    assert search["total"] == 1


def test_platforms_seeded(auth_client):
    platforms = auth_client.get("/platforms").json()
    names = {p["name"] for p in platforms}
    assert "Nintendo Switch" in names
    assert "PlayStation 5" in names
