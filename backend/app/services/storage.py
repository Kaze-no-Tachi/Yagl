"""Photo storage abstraction.

Only a local-filesystem backend ships now, but everything goes through the
`Storage` protocol + `get_storage()` factory so an S3-compatible backend can be
dropped in by config later without touching call sites.
"""
from __future__ import annotations

import os
import secrets
from typing import Protocol

from app.core.config import settings


class Storage(Protocol):
    def save(self, data: bytes, filename: str) -> str:
        """Persist bytes and return the relative storage path."""

    def delete(self, path: str) -> None:
        ...


class LocalStorage:
    def __init__(self, root: str) -> None:
        self.root = root
        os.makedirs(root, exist_ok=True)

    def save(self, data: bytes, filename: str) -> str:
        ext = os.path.splitext(filename)[1].lower() or ".bin"
        # Shard by a random prefix to avoid huge flat directories.
        token = secrets.token_hex(16)
        rel = f"{token[:2]}/{token}{ext}"
        full = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as fh:
            fh.write(data)
        return rel

    def delete(self, path: str) -> None:
        full = os.path.join(self.root, path)
        if os.path.exists(full):
            os.remove(full)


def get_storage() -> Storage:
    # Only "local" implemented; the factory is the seam for S3 later.
    return LocalStorage(settings.media_root)
