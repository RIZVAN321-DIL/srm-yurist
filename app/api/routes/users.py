from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.user_repo import UserRepository
from app.api.schemas.user import UserCreate
from app.models.user import User
from app.core.security import hash_password
from app.core.auth_middleware import get_admin_user

router = APIRouter(prefix="/api", tags=["users"])

@router.get("/users")
async def get_users(session=Depends(get_session), user=Depends(get_admin_user)):
    return [{"id": u.id, "full_name": u.full_name, "login": u.login, "role": u.role} for u in await UserRepository(session).get_all()]

@router.post("/users")
async def create_user(data: UserCreate, session=Depends(get_session), user=Depends(get_admin_user)):
    repo = UserRepository(session)
    if await repo.get_by_login(data.login): raise HTTPException(400)
    u = User(full_name=data.full_name, login=data.login, password_hash=hash_password(data.password), role=data.role)
    result = await repo.create(u); await session.commit(); return {"ok": True, "id": result.id}
