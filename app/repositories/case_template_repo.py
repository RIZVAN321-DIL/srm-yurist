from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case_template import CaseTemplate

class CaseTemplateRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self):
        result = await self.session.execute(select(CaseTemplate).order_by(CaseTemplate.name)); return list(result.scalars().all())
    async def get_by_id(self, template_id: int) -> CaseTemplate | None:
        result = await self.session.execute(select(CaseTemplate).where(CaseTemplate.id == template_id))
        return result.scalar_one_or_none()
    async def create(self, template: CaseTemplate) -> CaseTemplate:
        self.session.add(template); await self.session.flush(); return template
    async def delete(self, template_id: int) -> bool:
        result = await self.session.execute(delete(CaseTemplate).where(CaseTemplate.id == template_id))
        await self.session.flush(); return result.rowcount > 0
