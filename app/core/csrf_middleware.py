from fastapi import Request, HTTPException
from app.core.security import verify_csrf_token

async def csrf_protection(request: Request):
    if request.method in ("GET", "HEAD", "OPTIONS"): return
    if request.url.path.startswith("/api/auth/"): return
    token = request.headers.get("X-CSRF-Token")
    if not token or not verify_csrf_token(token): raise HTTPException(status_code=403, detail="CSRF token invalid")
