from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.api.schemas.client import ClientCreate, ClientUpdate
from app.models.client import Client
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["clients"])

@router.get("/clients")
async def get_clients(status: str | None = Query(default=None), search: str | None = Query(default=None), skip: int = 0, limit: int = 50, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = ClientRepository(session)
    clients = await repo.get_all(status=status, search=search, skip=skip, limit=limit)
    return [{"id": c.id, "full_name": c.full_name, "phone": c.phone, "email": c.email, "status": c.status} for c in clients]

@router.get("/clients/{client_id}")
async def get_client(client_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = ClientRepository(session)
    client = await repo.get_by_id(client_id)
    if not client:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    return {"id": client.id, "full_name": client.full_name, "phone": client.phone, "email": client.email, "status": client.status}

@router.post("/clients")
async def create_client(data: ClientCreate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = ClientRepository(session)
    client = Client(full_name=data.full_name, phone=data.phone, email=data.email, status=data.status)
    result = await repo.create(client)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/clients/{client_id}")
async def update_client(client_id: int, data: ClientUpdate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = ClientRepository(session)
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    client = await repo.update(client_id, **updates)
    if not client:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    await session.commit()
    return {"ok": True}

@router.delete("/clients/{client_id}")
async def delete_client(client_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = ClientRepository(session)
    ok = await repo.delete(client_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    await session.commit()
    return {"ok": True}
