from datetime import date

from sqlalchemy import Date, ForeignKey, Index, Integer, JSON, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

# Enum-like string domains kept as plain strings for cross-DB portability and
# painless extension. Validation lives in the Pydantic schemas.
ITEM_KINDS = ("game", "hardware", "accessory")
ITEM_FORMATS = ("physical", "digital", "retro")
ITEM_CONDITIONS = ("sealed", "cib", "loose", "digital", "damaged")
ITEM_SOURCES = ("manual", "scan", "steam", "gog", "epic", "csv")


class Item(Base, TimestampMixin):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)

    kind: Mapped[str] = mapped_column(String(20), default="game")
    format: Mapped[str] = mapped_column(String(20), default="physical")

    title: Mapped[str] = mapped_column(String(500), index=True)
    platform_id: Mapped[int | None] = mapped_column(
        ForeignKey("platforms.id"), nullable=True, index=True
    )
    barcode: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    region: Mapped[str | None] = mapped_column(String(16), nullable=True)

    condition: Mapped[str | None] = mapped_column(String(20), nullable=True)
    condition_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Metadata refs (from IGDB).
    igdb_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    cover_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    genres: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)

    # Acquisition / provenance.
    acquired_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    price_paid: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    storage_location: Mapped[str | None] = mapped_column(String(255), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    source: Mapped[str] = mapped_column(String(20), default="manual")
    # e.g. Steam appid — used to de-duplicate re-imports.
    store_app_id: Mapped[str | None] = mapped_column(String(64), nullable=True)

    user: Mapped["User"] = relationship(back_populates="items")  # type: ignore[name-defined]  # noqa: F821
    platform: Mapped["Platform | None"] = relationship()  # type: ignore[name-defined]  # noqa: F821
    photos: Mapped[list["Photo"]] = relationship(  # type: ignore[name-defined]  # noqa: F821
        back_populates="item", cascade="all, delete-orphan"
    )
    loans: Mapped[list["Loan"]] = relationship(  # type: ignore[name-defined]  # noqa: F821
        back_populates="item", cascade="all, delete-orphan", order_by="Loan.id.desc()"
    )


# Prevents importing the same digital title twice for one user.
Index("ix_items_user_source_app", Item.user_id, Item.source, Item.store_app_id)
