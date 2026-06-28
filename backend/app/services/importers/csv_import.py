"""Generic CSV importer.

Accepts any CSV (e.g. an Epic Games Library Exporter dump, a GOG export, or a
hand-rolled spreadsheet) plus a column mapping, and turns rows into OwnedGame
records. This is the "store of your choosing" path that works today without any
store-specific OAuth.
"""
from __future__ import annotations

import csv
import io

from app.schemas.imports import CsvColumnMapping
from app.services.importers.base import OwnedGame


class CsvImporter:
    provider = "csv"

    def __init__(self, csv_text: str, mapping: CsvColumnMapping) -> None:
        self.csv_text = csv_text
        self.mapping = mapping

    def fetch_owned(self) -> list[OwnedGame]:
        reader = csv.DictReader(io.StringIO(self.csv_text))
        if reader.fieldnames is None:
            return []
        headers = {h.strip(): h for h in reader.fieldnames}
        title_col = headers.get(self.mapping.title)
        if title_col is None:
            raise ValueError(
                f"CSV has no column named '{self.mapping.title}'. "
                f"Available columns: {', '.join(headers)}"
            )
        platform_col = headers.get(self.mapping.platform) if self.mapping.platform else None
        appid_col = headers.get(self.mapping.store_app_id) if self.mapping.store_app_id else None

        owned: list[OwnedGame] = []
        for row in reader:
            title = (row.get(title_col) or "").strip()
            if not title:
                continue
            owned.append(
                OwnedGame(
                    title=title,
                    platform_name=(row.get(platform_col).strip() if platform_col else None),
                    store_app_id=(row.get(appid_col).strip() if appid_col else None) or None,
                )
            )
        return owned
