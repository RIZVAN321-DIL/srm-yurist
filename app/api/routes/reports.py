from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["reports"])

@router.get("/reports/lawyers")
async def get_lawyer_report(session=Depends(get_session), user=Depends(get_current_user)):
    return await CaseRepository(session).get_owner_stats()
