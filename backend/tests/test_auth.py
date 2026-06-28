def test_register_login_me(client):
    r = client.post("/auth/register", json={"email": "a@b.com", "password": "password123"})
    assert r.status_code == 201
    token = r.json()["access_token"]

    # Duplicate email rejected.
    r2 = client.post("/auth/register", json={"email": "a@b.com", "password": "password123"})
    assert r2.status_code == 409

    # Login works and returns a token.
    r3 = client.post("/auth/login", json={"email": "a@b.com", "password": "password123"})
    assert r3.status_code == 200

    # Bad password rejected.
    r4 = client.post("/auth/login", json={"email": "a@b.com", "password": "wrong"})
    assert r4.status_code == 401

    # /me requires and accepts the token.
    assert client.get("/auth/me").status_code == 401
    me = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "a@b.com"


def test_short_password_rejected(client):
    r = client.post("/auth/register", json={"email": "c@d.com", "password": "short"})
    assert r.status_code == 422
