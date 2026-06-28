from datetime import date

from sqlalchemy import Date, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Loan(Base, TimestampMixin):
    """Tracks who has borrowed an item. An open loan has returned_on == NULL."""

    __tablename__ = "loans"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id", ondelete="CASCADE"), index=True)
    borrower_name: Mapped[str] = mapped_column(String(255))
    loaned_on: Mapped[date] = mapped_column(Date)
    due_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    returned_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    item: Mapped["Item"] = relationship(back_populates="loans")  # type: ignore[name-defined]  # noqa: F821
