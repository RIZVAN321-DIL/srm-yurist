from sqlalchemy import select, update, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self, status=None, search=None, skip=0, limit=50):
        query = select(Client)
        if status: query = query.where(Client.status == status)
        if search: query = query.where(Client.full_name.ilike(f"%{search}%") | Client.phone.ilike(f"%{search}%"))
        result = await self.session.execute(query.order_by(Client.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())
    async def get_by_id(self, client_id: int) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.id == client_id)); return result.scalar_one_or_none()
    async def get_by_access_code(self, code: str) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.access_code == code)); return result.scalar_one_or_none()
    async def create(self, client: Client) -> Client:
        self.session.add(client); await self.session.flush(); return client
    async def update(self, client_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Client).where(Client.id == client_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, client_id: int) -> bool:
        result = await self.session.execute(delete(Client).where(Client.id == client_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Client)); return result.scalar() or 0
