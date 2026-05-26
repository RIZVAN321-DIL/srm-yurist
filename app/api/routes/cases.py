from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository
from app.repositories.activity_repo import ActivityRepository
from app.api.schemas.case import CaseCreate, CaseUpdate
from app.models.case import Case
from app.models.activity import Activity
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["cases"])

@router.get("/cases")
async def get_cases(client_id: int | None = Query(default=None), status: str | None = Query(default=None), case_type: str | None = Query(default=None), skip: int = 0, limit: int = 50, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    cases = await repo.get_all(client_id=client_id, status=status, case_type=case_type, skip=skip, limit=limit)
    return [{"id": c.id, "title": c.title, "case_type": c.case_type, "status": c.status, "client_name": c.client.full_name if c.client else "—"} for c in cases]

@router.get("/cases/{case_id}")
async def get_case(case_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    case = await repo.get_by_id(case_id)
    if not case:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    return {
        "id": case.id, "title": case.title, "case_type": case.case_type, "status": case.status, "description": case.description,
        "client": {"id": case.client.id, "full_name": case.client.full_name, "phone": case.client.phone} if case.client else None,
        "stages": [{"id": s.id, "name": s.name, "status": s.status, "is_completed": s.is_completed, "assigned_to": s.assigned_to} for s in case.stages],
        "documents": [{"id": d.id, "name": d.name, "file_path": d.file_path} for d in case.documents],
        "activities": [{"id": a.id, "action": a.action, "description": a.description, "user_name": a.user.full_name if a.user else "—"} for a in case.activities]
    }

@router.post("/cases")
async def create_case(data: CaseCreate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    case = Case(client_id=data.client_id, title=data.title, case_type=data.case_type, description=data.description, status=data.status)
    result = await repo.create(case)
    await ActivityRepository(session).create(Activity(case_id=result.id, user_id=user["user_id"], action="create", description="Дело создано"))
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/cases/{case_id}")
async def update_case(case_id: int, data: CaseUpdate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    case = await repo.update(case_id, **updates)
    if not case:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="update", description=str(updates)))
    await session.commit()
    return {"ok": True}

@router.delete("/cases/{case_id}")
async def delete_case(case_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    ok = await repo.delete(case_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    await session.commit()
    return {"ok": True}
