from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Platform(Base):
    """A console/system (NES, PS5, PC, …). Seeded at startup."""

    __tablename__ = "platforms"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    # Maps to IGDB's platform id so metadata lookups can be platform-scoped.
    igdb_platform_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
