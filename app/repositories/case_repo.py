from sqlalchemy import select, update, func, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case import Case
from app.models.activity import Activity
from app.models.document import Document
from app.config import settings
import os

class CaseRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self, client_id=None, status=None, case_type=None, owner_id=None, search=None, skip=0, limit=50):
        query = select(Case).options(selectinload(Case.client), selectinload(Case.owner))
        if client_id: query = query.where(Case.client_id == client_id)
        if status: query = query.where(Case.status == status)
        if case_type: query = query.where(Case.case_type == case_type)
        if owner_id: query = query.where(Case.owner_id == owner_id)
        if search: query = query.where(Case.title.ilike(f"%{search}%"))
        result = await self.session.execute(query.order_by(Case.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())
    async def get_by_id(self, case_id: int) -> Case | None:
        result = await self.session.execute(select(Case).options(selectinload(Case.client), selectinload(Case.owner), selectinload(Case.stages), selectinload(Case.documents), selectinload(Case.payments), selectinload(Case.activities).selectinload(Activity.user)).where(Case.id == case_id))
        return result.scalar_one_or_none()
    async def create(self, case: Case) -> Case:
        self.session.add(case); await self.session.flush(); return case
    async def update(self, case_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Case).where(Case.id == case_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, case_id: int) -> bool:
        docs = await self.session.execute(select(Document).where(Document.case_id == case_id))
        for d in docs.scalars().all():
            filepath = d.file_path if d.file_path.startswith("/") else os.path.join(settings.UPLOAD_DIR, d.file_path)
            try:
                if os.path.exists(filepath): os.remove(filepath)
            except OSError:
                pass
        result = await self.session.execute(delete(Case).where(Case.id == case_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Case)); return result.scalar() or 0
    async def get_status_counts(self) -> dict:
        result = await self.session.execute(select(Case.status, func.count(Case.id)).group_by(Case.status))
        return {row[0]: row[1] for row in result.all()}
    async def get_owner_stats(self) -> list:
        from app.models.user import User
        result = await self.session.execute(select(Case.owner_id, User.full_name, func.count(Case.id)).join(User, Case.owner_id == User.id).group_by(Case.owner_id))
        return [{"owner_id": r[0], "full_name": r[1], "total": r[2]} for r in result.all()]
