from sqlalchemy import select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.payment import Payment

class PaymentRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self):
        result = await self.session.execute(select(Payment).order_by(Payment.created_at.desc()).limit(100)); return list(result.scalars().all())
    async def get_by_case(self, case_id: int):
        result = await self.session.execute(select(Payment).where(Payment.case_id == case_id).order_by(Payment.created_at.desc()))
        return list(result.scalars().all())
    async def create(self, payment: Payment) -> Payment:
        self.session.add(payment); await self.session.flush(); return payment
    async def update(self, payment_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Payment).where(Payment.id == payment_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, payment_id: int) -> bool:
        result = await self.session.execute(delete(Payment).where(Payment.id == payment_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_revenue(self) -> int:
        result = await self.session.execute(select(func.sum(Payment.amount)).where(Payment.status == "paid"))
        return result.scalar() or 0
