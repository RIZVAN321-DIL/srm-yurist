from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository, ActivityRepository, CaseTemplateRepository, StageRepository
from app.api.schemas.case import CaseCreate, CaseUpdate, CaseTransfer
from app.models.case import Case
from app.models.activity import Activity
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user
from datetime import datetime, timezone
import json

router = APIRouter(prefix="/api", tags=["cases"])

@router.get("/cases")
async def get_cases(request: Request, client_id=None, status=None, case_type=None, search=None, skip=0, limit=50, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); owner_id = user["user_id"] if user["role"] != "admin" else None
    cases = await repo.get_all(client_id=client_id, status=status, case_type=case_type, owner_id=owner_id, search=search, skip=skip, limit=limit)
    return [{"id": c.id, "title": c.title, "case_type": c.case_type, "status": c.status, "client_name": c.client.full_name if c.client else "—", "owner_name": c.owner.full_name if c.owner else "—"} for c in cases]

@router.get("/cases/{case_id}")
async def get_case(case_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    return {"id": case.id, "title": case.title, "case_type": case.case_type, "status": case.status, "description": case.description, "statute_deadline": case.statute_deadline.isoformat() if case.statute_deadline else None, "parent_case_id": case.parent_case_id, "client": {"id": case.client.id, "full_name": case.client.full_name} if case.client else None, "owner": {"id": case.owner.id, "full_name": case.owner.full_name} if case.owner else None, "stages": [{"id": s.id, "name": s.name, "status": s.status, "is_completed": s.is_completed} for s in case.stages], "documents": [{"id": d.id, "name": d.name, "file_path": f"/api/documents/{d.id}/download"} for d in case.documents], "payments": [{"id": p.id, "amount": p.amount, "status": p.status, "description": p.description} for p in case.payments], "activities": [{"id": a.id, "action": a.action, "description": a.description, "user_name": a.user.full_name if a.user else "—"} for a in case.activities]}

@router.post("/cases")
async def create_case(data: CaseCreate, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); statute = None
    if data.statute_deadline:
        statute = datetime.fromisoformat(data.statute_deadline).replace(tzinfo=timezone.utc)
    case = Case(client_id=data.client_id, title=data.title, case_type=data.case_type, description=data.description, status=data.status, owner_id=user["user_id"], parent_case_id=data.parent_case_id, statute_deadline=statute)
    result = await repo.create(case)
    if data.template_id:
        tmpl = await CaseTemplateRepository(session).get_by_id(data.template_id)
        if tmpl:
            stages_data = json.loads(tmpl.stages_json); sr = StageRepository(session)
            for i, s in enumerate(stages_data):
                await sr.create(Stage(case_id=result.id, name=s["name"], description=s.get("description",""), order=i, assigned_to=user["user_id"]))
    await ActivityRepository(session).create(Activity(case_id=result.id, user_id=user["user_id"], action="create", description="Дело создано"))
    await session.commit(); return {"ok": True, "id": result.id}

@router.put("/cases/{case_id}")
async def update_case(case_id: int, data: CaseUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    updates = {k: v for k, v in data.model_dump().items() if v is not None and k != "statute_deadline"}
    if data.statute_deadline:
        updates["statute_deadline"] = datetime.fromisoformat(data.statute_deadline).replace(tzinfo=timezone.utc)
    ok = await repo.update(case_id, **updates)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="update", description=str(updates)[:500]))
    await session.commit(); return {"ok": True}

@router.post("/cases/{case_id}/transfer")
async def transfer_case(case_id: int, data: CaseTransfer, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    await repo.update(case_id, owner_id=data.new_owner_id)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="transfer", description=f"Дело передано пользователю {data.new_owner_id}"))
    await session.commit(); return {"ok": True}

@router.delete("/cases/{case_id}")
async def delete_case(case_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="delete", description=f"Дело удалено: {case.title}"))
    await repo.delete(case_id); await session.commit(); return {"ok": True}
