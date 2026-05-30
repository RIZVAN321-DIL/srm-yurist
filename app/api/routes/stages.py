from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.stage_repo import StageRepository
from app.api.schemas.stage import StageCreate, StageUpdate
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user
from datetime import datetime, timezone

router = APIRouter(prefix="/api", tags=["stages"])

@router.post("/stages")
async def create_stage(data: StageCreate, session=Depends(get_session), user=Depends(get_current_user)):
    deadline = None
    if data.deadline:
        deadline = datetime.fromisoformat(data.deadline).replace(tzinfo=timezone.utc)
    stage = Stage(case_id=data.case_id, name=data.name, description=data.description, assigned_to=data.assigned_to, order=data.order, deadline=deadline)
    result = await StageRepository(session).create(stage); await session.commit(); return {"ok": True, "id": result.id}

@router.put("/stages/{stage_id}")
async def update_stage(stage_id: int, data: StageUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    updates = {k: v for k, v in data.model_dump().items() if v is not None and k != "deadline"}
    if data.deadline:
        updates["deadline"] = datetime.fromisoformat(data.deadline).replace(tzinfo=timezone.utc)
    ok = await StageRepository(session).update(stage_id, **updates)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.delete("/stages/{stage_id}")
async def delete_stage(stage_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    ok = await StageRepository(session).delete(stage_id)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}
