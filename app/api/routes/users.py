from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.user_repo import UserRepository
from app.api.schemas.user import UserCreate
from app.models.user import User
from app.core.security import hash_password
from app.core.auth_middleware import get_current_user, get_admin_user

router = APIRouter(prefix="/api", tags=["users"])

@router.get("/users")
async def get_users(session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = UserRepository(session)
    users = await repo.get_all()
    return [{"id": u.id, "full_name": u.full_name, "login": u.login, "role": u.role} for u in users]

@router.post("/users")
async def create_user(data: UserCreate, session: AsyncSession = Depends(get_session), user=Depends(get_admin_user)):
    repo = UserRepository(session)
    existing = await repo.get_by_login(data.login)
    if existing:
        raise HTTPException(status_code=400, detail="Пользователь с таким логином уже существует")
    hashed = hash_password(data.password)
    new_user = User(full_name=data.full_name, login=data.login, password_hash=hashed, role=data.role)
    result = await repo.create(new_user)
    await session.commit()
    return {"ok": True, "id": result.id}
