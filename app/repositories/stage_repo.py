from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.stage import Stage

class StageRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_case(self, case_id: int) -> list[Stage]:
        result = await self.session.execute(select(Stage).where(Stage.case_id == case_id).order_by(Stage.order))
        return list(result.scalars().all())

    async def create(self, stage: Stage) -> Stage:
        self.session.add(stage)
        await self.session.flush()
        return stage

    async def update(self, stage_id: int, **kwargs) -> Stage | None:
        await self.session.execute(update(Stage).where(Stage.id == stage_id).values(**kwargs))
        await self.session.flush()
        result = await self.session.execute(select(Stage).where(Stage.id == stage_id))
        return result.scalar_one_or_none()

    async def delete(self, stage_id: int) -> bool:
        stage = await self.session.execute(select(Stage).where(Stage.id == stage_id))
        s = stage.scalar_one_or_none()
        if s:
            await self.session.execute(delete(Stage).where(Stage.id == stage_id))
            await self.session.flush()
            return True
        return False
