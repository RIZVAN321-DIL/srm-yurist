from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.stage_repo import StageRepository
from app.api.schemas.stage import StageCreate, StageUpdate
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["stages"])

@router.post("/stages")
async def create_stage(data: StageCreate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    stage = Stage(case_id=data.case_id, name=data.name, description=data.description, assigned_to=data.assigned_to, order=data.order)
    result = await repo.create(stage)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/stages/{stage_id}")
async def update_stage(stage_id: int, data: StageUpdate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    stage = await repo.update(stage_id, **updates)
    if not stage:
        raise HTTPException(status_code=404, detail="Этап не найден")
    await session.commit()
    return {"ok": True}

@router.delete("/stages/{stage_id}")
async def delete_stage(stage_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    ok = await repo.delete(stage_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Этап не найден")
    await session.commit()
    return {"ok": True}
