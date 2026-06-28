from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class StoreConnection(Base, TimestampMixin):
    """A saved link to a digital store so imports can be re-synced.

    The credential (Steam API key today; OAuth refresh token for GOG/Epic later)
    is stored encrypted via core.security.encrypt_secret.
    """

    __tablename__ = "store_connections"
    __table_args__ = (UniqueConstraint("user_id", "provider", name="uq_user_provider"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(20))  # steam | gog | epic
    external_account_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    credential_enc: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped["User"] = relationship(back_populates="connections")  # type: ignore[name-defined]  # noqa: F821
