import bcrypt, jwt, os
from datetime import datetime, timedelta, timezone
from cryptography.fernet import Fernet
from app.config import settings

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_token(user_id: int, role: str) -> str:
    payload = {"user_id": user_id, "role": role, "exp": datetime.now(timezone.utc) + timedelta(hours=settings.JWT_EXPIRE_HOURS)}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

def decode_token(token: str) -> dict | None:
    try: return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
    except: return None

def get_fernet(): return Fernet(settings.ENCRYPTION_KEY.encode('utf-8'))
def encrypt_file(data: bytes) -> bytes: return get_fernet().encrypt(data)
def decrypt_file(data: bytes) -> bytes: return get_fernet().decrypt(data)
def generate_csrf_token() -> str: return jwt.encode({"csrf": os.urandom(16).hex(), "exp": datetime.now(timezone.utc) + timedelta(hours=8)}, settings.CSRF_SECRET, algorithm="HS256")
def verify_csrf_token(token: str) -> bool:
    try: jwt.decode(token, settings.CSRF_SECRET, algorithms=["HS256"]); return True
    except: return False
def generate_access_code() -> str: return os.urandom(16).hex()
