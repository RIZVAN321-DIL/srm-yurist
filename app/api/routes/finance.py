from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.payment_repo import PaymentRepository
from app.api.schemas.payment import PaymentCreate, PaymentUpdate
from app.models.payment import Payment
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["finance"])

@router.get("/payments")
async def get_payments(session=Depends(get_session), user=Depends(get_current_user)):
    return [{"id": p.id, "case_id": p.case_id, "amount": p.amount, "status": p.status, "description": p.description, "created_at": p.created_at.isoformat() if p.created_at else None} for p in await PaymentRepository(session).get_all()]

@router.post("/payments")
async def create_payment(data: PaymentCreate, session=Depends(get_session), user=Depends(get_current_user)):
    p = Payment(case_id=data.case_id, amount=data.amount, description=data.description, status=data.status)
    result = await PaymentRepository(session).create(p); await session.commit(); return {"ok": True, "id": result.id}

@router.put("/payments/{payment_id}")
async def update_payment(payment_id: int, data: PaymentUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    ok = await PaymentRepository(session).update(payment_id, **updates)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.delete("/payments/{payment_id}")
async def delete_payment(payment_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    ok = await PaymentRepository(session).delete(payment_id)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.get("/finance/stats")
async def get_finance_stats(session=Depends(get_session), user=Depends(get_current_user)):
    return {"total_revenue": await PaymentRepository(session).get_total_revenue()}
