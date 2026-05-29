from sqlalchemy import String, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class CaseTemplate(Base):
    __tablename__ = "case_templates"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255))
    case_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    stages_json: Mapped[str] = mapped_column(String(5000))
