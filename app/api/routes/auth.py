from fastapi import APIRouter, Depends, HTTPException, Response, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.user_repo import UserRepository
from app.api.schemas.user import UserLogin, PasswordChange
from app.core.security import verify_password, create_token, hash_password, generate_csrf_token
from app.core.auth_middleware import get_current_user
from app.config import settings
from datetime import datetime, timedelta

router = APIRouter(prefix="/api", tags=["auth"])

@router.post("/auth/login")
async def login(data: UserLogin, response: Response, request: Request, session: AsyncSession = Depends(get_session)):
    repo = UserRepository(session); user = await repo.get_by_login(data.login)
    if not user: raise HTTPException(404, detail="Пользователь не найден")
    if user.locked_until and user.locked_until > datetime.utcnow(): raise HTTPException(423)
    if not verify_password(data.password, user.password_hash):
        attempts = (user.login_attempts or 0) + 1; locked = None
        if attempts >= settings.LOGIN_MAX_ATTEMPTS: locked = datetime.utcnow() + timedelta(minutes=settings.LOGIN_TIMEOUT_MINUTES)
        await repo.update(user.id, login_attempts=attempts, locked_until=locked)
        await session.commit(); raise HTTPException(403)
    await repo.update(user.id, login_attempts=0, locked_until=None); await session.commit()
    token = create_token(user.id, user.role); csrf_token = generate_csrf_token()
    secure = request.url.scheme == "https"
    response.set_cookie("crm_token", token, httponly=True, secure=secure, samesite="lax", max_age=settings.JWT_EXPIRE_HOURS*3600)
    response.set_cookie("csrf_token", csrf_token, secure=secure, samesite="lax", max_age=settings.JWT_EXPIRE_HOURS*3600)
    return {"ok": True, "csrf_token": csrf_token, "user": {"id": user.id, "full_name": user.full_name, "login": user.login, "role": user.role, "force_password_change": user.force_password_change}}

@router.post("/auth/logout")
async def logout(response: Response):
    response.delete_cookie("crm_token"); response.delete_cookie("csrf_token"); return {"ok": True}

@router.post("/auth/change-password")
async def change_password(data: PasswordChange, session=Depends(get_session), user=Depends(get_current_user)):
    repo = UserRepository(session); u = await repo.get_by_id(user["user_id"])
    if not u: raise HTTPException(404)
    if not verify_password(data.old_password, u.password_hash): raise HTTPException(403)
    await repo.update(u.id, password_hash=hash_password(data.new_password), force_password_change=False)
    await session.commit(); return {"ok": True}
