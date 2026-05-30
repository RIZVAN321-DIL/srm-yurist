from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.security import decode_token

security = HTTPBearer(auto_error=False)

async def get_current_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = request.cookies.get("crm_token")
    if not token and credentials: token = credentials.credentials
    if not token: raise HTTPException(status_code=401, detail="Требуется авторизация")
    payload = decode_token(token)
    if not payload: raise HTTPException(status_code=401, detail="Неверный или истекший токен")
    return payload

async def get_admin_user(user=Depends(get_current_user)):
    if user["role"] != "admin": raise HTTPException(status_code=403, detail="Нет доступа")
    return user
