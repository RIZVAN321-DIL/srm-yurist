from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User

class UserRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self) -> list[User]:
        result = await self.session.execute(select(User).where(User.is_active == True)); return list(result.scalars().all())
    async def get_by_id(self, user_id: int) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id)); return result.scalar_one_or_none()
    async def get_by_login(self, login: str) -> User | None:
        result = await self.session.execute(select(User).where(User.login == login)); return result.scalar_one_or_none()
    async def create(self, user: User) -> User:
        self.session.add(user); await self.session.flush(); return user
    async def update(self, user_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(User).where(User.id == user_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
