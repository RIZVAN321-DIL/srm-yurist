from sqlalchemy import select, update, func, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case import Case
from app.models.activity import Activity

class CaseRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all(self, client_id: int | None = None, status: str | None = None, case_type: str | None = None, skip: int = 0, limit: int = 50) -> list[Case]:
        query = select(Case).options(selectinload(Case.client))
        if client_id:
            query = query.where(Case.client_id == client_id)
        if status:
            query = query.where(Case.status == status)
        if case_type:
            query = query.where(Case.case_type == case_type)
        result = await self.session.execute(query.order_by(Case.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())

    async def get_by_id(self, case_id: int) -> Case | None:
        result = await self.session.execute(
            select(Case).options(
                selectinload(Case.client),
                selectinload(Case.stages),
                selectinload(Case.documents),
                selectinload(Case.activities).selectinload(Activity.user)
            ).where(Case.id == case_id)
        )
        return result.scalar_one_or_none()

    async def create(self, case: Case) -> Case:
        self.session.add(case)
        await self.session.flush()
        return case

    async def update(self, case_id: int, **kwargs) -> Case | None:
        await self.session.execute(update(Case).where(Case.id == case_id).values(**kwargs))
        await self.session.flush()
        return await self.get_by_id(case_id)

    async def delete(self, case_id: int) -> bool:
        case = await self.get_by_id(case_id)
        if case:
            await self.session.execute(delete(Case).where(Case.id == case_id))
            await self.session.flush()
            return True
        return False

    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Case))
        return result.scalar() or 0

    async def get_status_counts(self) -> dict:
        result = await self.session.execute(select(Case.status, func.count(Case.id)).group_by(Case.status))
        return {row[0]: row[1] for row in result.all()}
