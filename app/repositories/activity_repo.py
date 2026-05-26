from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.activity import Activity

class ActivityRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_case(self, case_id: int) -> list[Activity]:
        result = await self.session.execute(select(Activity).where(Activity.case_id == case_id).order_by(Activity.created_at.desc()))
        return list(result.scalars().all())

    async def create(self, activity: Activity) -> Activity:
        self.session.add(activity)
        await self.session.flush()
        return activity
