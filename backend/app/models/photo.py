from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Photo(Base, TimestampMixin):
    """A user-supplied photo of a physical item (distinct from IGDB cover art)."""

    __tablename__ = "photos"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id", ondelete="CASCADE"), index=True)
    # Relative storage path; served via media_url_base.
    path: Mapped[str] = mapped_column(String(1000))
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)

    item: Mapped["Item"] = relationship(back_populates="photos")  # type: ignore[name-defined]  # noqa: F821
