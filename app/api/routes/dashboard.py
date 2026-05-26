from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.case_repo import CaseRepository
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["dashboard"])

@router.get("/dashboard/stats")
async def get_dashboard_stats(session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    client_repo = ClientRepository(session)
    case_repo = CaseRepository(session)
    total_clients = await client_repo.get_total_count()
    total_cases = await case_repo.get_total_count()
    case_statuses = await case_repo.get_status_counts()
    return {
        "total_clients": total_clients,
        "total_cases": total_cases,
        "active_cases": case_statuses.get("active", 0) + case_statuses.get("new", 0),
        "closed_cases": case_statuses.get("closed", 0)
    }
