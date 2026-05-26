from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.user_repo import UserRepository
from app.api.schemas.user import UserLogin
from app.core.security import verify_password, create_token

router = APIRouter(prefix="/api", tags=["auth"])

@router.post("/auth/login")
async def login(data: UserLogin, session: AsyncSession = Depends(get_session)):
    repo = UserRepository(session)
    user = await repo.get_by_login(data.login)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    if not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=403, detail="Неверный пароль")
    token = create_token(user.id, user.role)
    return {"ok": True, "token": token, "user": {"id": user.id, "full_name": user.full_name, "login": user.login, "role": user.role}}
