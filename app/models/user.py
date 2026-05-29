from sqlalchemy import String, Integer, DateTime, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
from datetime import datetime, timezone

class User(Base):
    __tablename__ = "users"
    __table_args__ = (Index("ix_users_login", "login"), Index("ix_users_role", "role"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(255))
    login: Mapped[str] = mapped_column(String(100), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(50), default="lawyer")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    login_attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    force_password_change: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
