from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.case_repo import CaseRepository
from datetime import datetime, timezone

router = APIRouter(prefix="/api", tags=["portal"])

@router.get("/portal/{access_code}")
async def get_client_portal(access_code: str, session=Depends(get_session)):
    client = await ClientRepository(session).get_by_access_code(access_code)
    if not client: raise HTTPException(404)
    if client.access_code_expiry and client.access_code_expiry < datetime.now(timezone.utc):
        raise HTTPException(410, detail="Срок действия ссылки истёк")
    cases = await CaseRepository(session).get_all(client_id=client.id)
    return {"client": {"id": client.id, "full_name": client.full_name}, "cases": [{"id": c.id, "title": c.title, "status": c.status, "case_type": c.case_type, "description": c.description} for c in cases]}
