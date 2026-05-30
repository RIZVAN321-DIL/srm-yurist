from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_template_repo import CaseTemplateRepository
from app.models.case_template import CaseTemplate
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["templates"])

@router.get("/templates")
async def get_templates(session=Depends(get_session), user=Depends(get_current_user)):
    return [{"id": t.id, "name": t.name, "case_type": t.case_type} for t in await CaseTemplateRepository(session).get_all()]

@router.post("/templates")
async def create_template(data: dict, session=Depends(get_session), user=Depends(get_current_user)):
    t = CaseTemplate(name=data["name"], case_type=data.get("case_type"), stages_json=data.get("stages_json","[]"))
    result = await CaseTemplateRepository(session).create(t); await session.commit(); return {"ok": True, "id": result.id}
