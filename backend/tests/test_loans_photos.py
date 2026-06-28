import io


def _create(auth_client, **overrides):
    payload = {"title": "Elden Ring", "kind": "game", "format": "physical"}
    payload.update(overrides)
    return auth_client.post("/items", json=payload).json()


def test_lending_flow(auth_client):
    item = _create(auth_client)
    iid = item["id"]

    loan = auth_client.post(
        f"/items/{iid}/loans", json={"borrower_name": "Sam", "loaned_on": "2026-06-01"}
    )
    assert loan.status_code == 201
    loan_id = loan.json()["id"]

    # Cannot lend an already-lent item.
    dup = auth_client.post(
        f"/items/{iid}/loans", json={"borrower_name": "Pat", "loaned_on": "2026-06-02"}
    )
    assert dup.status_code == 409

    # on_loan filter surfaces it.
    on_loan = auth_client.get("/items", params={"on_loan": True}).json()
    assert any(it["id"] == iid for it in on_loan["items"])

    # Return it.
    ret = auth_client.post(f"/loans/{loan_id}/return", json={"returned_on": "2026-06-10"})
    assert ret.status_code == 200
    assert ret.json()["returned_on"] == "2026-06-10"

    # Now lendable again.
    again = auth_client.post(
        f"/items/{iid}/loans", json={"borrower_name": "Pat", "loaned_on": "2026-06-11"}
    )
    assert again.status_code == 201


def test_photo_upload_and_url(auth_client):
    item = _create(auth_client)
    iid = item["id"]
    # 1x1 PNG.
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00"
        b"\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    r = auth_client.post(
        f"/items/{iid}/photos",
        files={"file": ("test.png", io.BytesIO(png), "image/png")},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["is_primary"] is True
    assert body["url"].startswith("/media/")

    # Photo appears on the item.
    got = auth_client.get(f"/items/{iid}").json()
    assert len(got["photos"]) == 1

    # Reject non-images.
    bad = auth_client.post(
        f"/items/{iid}/photos",
        files={"file": ("x.txt", io.BytesIO(b"hi"), "text/plain")},
    )
    assert bad.status_code == 415

    # Delete.
    pid = body["id"]
    assert auth_client.delete(f"/items/{iid}/photos/{pid}").status_code == 204
