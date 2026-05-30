from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.case_repo import CaseRepository
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["dashboard"])

@router.get("/dashboard/stats")
async def get_dashboard_stats(session=Depends(get_session), user=Depends(get_current_user)):
    cr = ClientRepository(session); csr = CaseRepository(session)
    return {"total_clients": await cr.get_total_count(), "total_cases": await csr.get_total_count(), "active_cases": (await csr.get_status_counts()).get("active",0)+(await csr.get_status_counts()).get("new",0), "closed_cases": (await csr.get_status_counts()).get("closed",0)}
