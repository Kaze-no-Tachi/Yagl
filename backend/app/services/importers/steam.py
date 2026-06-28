"""Steam importer — native, official Steam Web API.

Uses IPlayerService/GetOwnedGames. Requires a Steam Web API key and the user's
SteamID64 (profile + game details must be public). A vanity profile name is
resolved to a SteamID64 via ISteamUser/ResolveVanityURL.
"""
from __future__ import annotations

import httpx

from app.core.config import settings
from app.services.importers.base import Importer, OwnedGame

_OWNED_GAMES_URL = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
_RESOLVE_VANITY_URL = "https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/"


class SteamImportError(RuntimeError):
    pass


class SteamImporter:
    provider = "steam"

    def __init__(self, steam_id: str, api_key: str | None = None) -> None:
        self.api_key = api_key or settings.steam_api_key
        if not self.api_key:
            raise SteamImportError("Steam Web API key is not configured")
        self.steam_id = steam_id

    def _resolve_steam_id(self, client: httpx.Client) -> str:
        # Already a 17-digit SteamID64.
        if self.steam_id.isdigit() and len(self.steam_id) >= 17:
            return self.steam_id
        resp = client.get(
            _RESOLVE_VANITY_URL,
            params={"key": self.api_key, "vanityurl": self.steam_id},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json().get("response", {})
        if data.get("success") != 1 or not data.get("steamid"):
            raise SteamImportError(f"Could not resolve Steam profile '{self.steam_id}'")
        return data["steamid"]

    def fetch_owned(self) -> list[OwnedGame]:
        try:
            with httpx.Client() as client:
                steam_id64 = self._resolve_steam_id(client)
                resp = client.get(
                    _OWNED_GAMES_URL,
                    params={
                        "key": self.api_key,
                        "steamid": steam_id64,
                        "include_appinfo": 1,
                        "include_played_free_games": 1,
                        "format": "json",
                    },
                    timeout=20,
                )
                resp.raise_for_status()
        except httpx.HTTPError as exc:
            raise SteamImportError(f"Steam API request failed: {exc}") from exc

        games = (resp.json().get("response") or {}).get("games")
        if games is None:
            raise SteamImportError(
                "No games returned — the Steam profile's game details are likely private."
            )
        return [
            OwnedGame(
                title=g.get("name") or f"App {g.get('appid')}",
                store_app_id=str(g.get("appid")),
                platform_name="PC",
                extra={"playtime_forever": g.get("playtime_forever", 0)},
            )
            for g in games
        ]


# Satisfy the Importer protocol at type-check time.
_: type[Importer] = SteamImporter
