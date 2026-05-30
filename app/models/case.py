from sqlalchemy import String, Integer, DateTime, ForeignKey, Text, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Case(Base):
    __tablename__ = "cases"
    __table_args__ = (Index("ix_cases_status", "status"), Index("ix_cases_client_id", "client_id"), Index("ix_cases_owner_status", "owner_id", "status"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), default=1)
    parent_case_id: Mapped[int | None] = mapped_column(ForeignKey("cases.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(500))
    case_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="new")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    statute_deadline: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    client = relationship("Client", back_populates="cases")
    owner = relationship("User", foreign_keys=[owner_id])
    parent_case = relationship("Case", remote_side=[id], foreign_keys=[parent_case_id])
    stages = relationship("Stage", back_populates="case", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="case", cascade="all, delete-orphan")
    activities = relationship("Activity", back_populates="case", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="case", cascade="all, delete-orphan")
