#!/bin/bash

mkdir -p app/core app/models app/repositories app/api/routes app/api/schemas app/static/uploads app/static/js/modules
touch app/static/uploads/.gitkeep

cat > .env << 'ENVEOF'
BOT_TOKEN=ВАШ_ТОКЕН_БОТА
ADMIN_IDS=5724746367
DATABASE_URL=sqlite+aiosqlite:////app/data/crm_yurist.db
API_HOST=0.0.0.0
API_PORT=10000
BASE_URL=https://crm-yurist.onrender.com
SECRET_KEY=crm-yurist-secret-2025
BOT_USERNAME=YuristCRM_bot
JWT_SECRET=crm-jwt-secret-key-2025
JWT_EXPIRE_HOURS=24
MAX_FILE_SIZE_MB=20
ENCRYPTION_KEY=kWjF7Q2mX9pL4vR8yN1cB5sH3tE6uA0dG7oI9wS2fK=
CSRF_SECRET=csrf-secret-change-me
ENVEOF

cat > runtime.txt << 'EOF'
python-3.12
EOF

cat > Procfile << 'EOF'
web: uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}
EOF

cat > requirements.txt << 'EOF'
aiogram>=3.7.0
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
sqlalchemy[asyncio]>=2.0.36
aiosqlite>=0.20.0
pydantic>=2.10.0
pydantic-settings>=2.6.0
python-dotenv>=1.0.0
loguru>=0.7.0
python-multipart>=0.0.12
aiofiles>=23.0
bcrypt>=4.0.0
PyJWT>=2.8.0
cryptography>=41.0.0
python-magic>=0.4.27
slowapi>=0.1.9
openpyxl>=3.1.0
weasyprint>=60.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl libmagic1 libpango-1.0-0 libharfbuzz0b libpangoft2-1.0-0 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data /app/static/uploads
ENV DATABASE_URL=sqlite+aiosqlite:////app/data/crm_yurist.db
EXPOSE 10000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
EOF

cat > app/__init__.py << 'EOF'
EOF

cat > app/config.py << 'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator

class Settings(BaseSettings):
    BOT_TOKEN: str = ""
    DATABASE_URL: str = "sqlite+aiosqlite:////app/data/crm_yurist.db"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 10000
    BASE_URL: str = ""
    ADMIN_IDS: list[int] = []
    SECRET_KEY: str = "change-me"
    BOT_USERNAME: str = ""
    UPLOAD_DIR: str = "app/static/uploads"
    JWT_SECRET: str = "jwt-secret"
    JWT_EXPIRE_HOURS: int = 24
    MAX_FILE_SIZE_MB: int = 20
    ENCRYPTION_KEY: str = "kWjF7Q2mX9pL4vR8yN1cB5sH3tE6uA0dG7oI9wS2fK="
    CSRF_SECRET: str = "csrf-secret"
    LOGIN_MAX_ATTEMPTS: int = 5
    LOGIN_TIMEOUT_MINUTES: int = 15
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str): return [int(x.strip()) for x in value.split(",") if x.strip()]
        if isinstance(value, list): return value
        if isinstance(value, int): return [value]
        return []

settings = Settings()
EOF

cat > app/logger.py << 'EOF'
import logging, sys
def setup_logger():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
    return logging.getLogger("crm")
logger = setup_logger()
EOF

cat > app/database.py << 'EOF'
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

class Base(DeclarativeBase): pass

engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True, future=True)
async_session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

async def get_session():
    async with async_session() as session:
        yield session
EOF

cat > app/core/__init__.py << 'EOF'
EOF

cat > app/core/security.py << 'EOF'
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
EOF

cat > app/core/auth_middleware.py << 'EOF'
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
EOF

cat > app/core/csrf_middleware.py << 'EOF'
from fastapi import Request, HTTPException
from app.core.security import verify_csrf_token

async def csrf_protection(request: Request):
    if request.method in ("GET", "HEAD", "OPTIONS"): return
    if request.url.path.startswith("/api/auth/"): return
    token = request.headers.get("X-CSRF-Token")
    if not token or not verify_csrf_token(token): raise HTTPException(status_code=403, detail="CSRF token invalid")
EOF

cat > app/seed.py << 'EOF'
from sqlalchemy import select, func
from app.database import async_session
from app.models.user import User
from app.core.security import hash_password
from app.logger import logger

async def seed_admin():
    async with async_session() as session:
        count = await session.scalar(select(func.count()).select_from(User))
        if count == 0:
            admin = User(full_name="Администратор", login="admin", password_hash=hash_password("admin123"), role="admin", force_password_change=True)
            session.add(admin)
            await session.commit()
            logger.info("Создан администратор: admin / admin123 (обязательная смена пароля)")
EOF

cat > app/main.py << 'EOF'
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import engine, Base
from app.logger import logger
from app.seed import seed_admin
from app.api.routes.auth import router as auth_router
from app.api.routes.clients import router as clients_router
from app.api.routes.cases import router as cases_router
from app.api.routes.stages import router as stages_router
from app.api.routes.documents import router as documents_router
from app.api.routes.users import router as users_router
from app.api.routes.dashboard import router as dashboard_router
from app.api.routes.finance import router as finance_router
from app.api.routes.reports import router as reports_router
from app.api.routes.client_portal import router as portal_router
from app.api.routes.templates import router as templates_router
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("CRM start")
    async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
    await seed_admin()
    logger.info("CRM ready")
    yield
    logger.info("CRM stop")

app = FastAPI(title="CRM Yurist", version="6.3.1", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(auth_router); app.include_router(dashboard_router)
app.include_router(clients_router); app.include_router(cases_router)
app.include_router(stages_router); app.include_router(documents_router)
app.include_router(users_router); app.include_router(finance_router)
app.include_router(reports_router); app.include_router(portal_router)
app.include_router(templates_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health(): return {"status": "ok"}

@app.get("/admin")
async def admin_panel(): return FileResponse("app/static/admin.html")

@app.get("/client/{access_code}")
async def client_portal_page(access_code: str): return FileResponse("app/static/client.html")
EOF

echo "Часть 1 готова"cat > app/models/__init__.py << 'EOF'
from app.models.client import Client
from app.models.case import Case
from app.models.stage import Stage
from app.models.document import Document
from app.models.user import User
from app.models.activity import Activity
from app.models.payment import Payment
from app.models.case_template import CaseTemplate
EOF

cat > app/models/client.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone, timedelta
import os

class Client(Base):
    __tablename__ = "clients"
    __table_args__ = (Index("ix_clients_status", "status"), Index("ix_clients_full_name", "full_name"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="active")
    tags: Mapped[str | None] = mapped_column(String(500), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    access_code: Mapped[str] = mapped_column(String(32), unique=True, default=lambda: os.urandom(16).hex())
    access_code_expiry: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc) + timedelta(days=90))
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    cases = relationship("Case", back_populates="client", cascade="all, delete-orphan")
EOF

cat > app/models/case.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Text, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Case(Base):
    __tablename__ = "cases"
    __table_args__ = (Index("ix_cases_status", "status"), Index("ix_cases_client_id", "client_id"), Index("ix_cases_owner_status", "owner_id", "status"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), default=1)
    parent_case_id: Mapped[int | None] = mapped_column(ForeignKey("cases.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(500))
    case_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="new")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    statute_deadline: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    client = relationship("Client", back_populates="cases")
    owner = relationship("User", foreign_keys=[owner_id])
    parent_case = relationship("Case", remote_side=[id], foreign_keys=[parent_case_id])
    stages = relationship("Stage", back_populates="case", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="case", cascade="all, delete-orphan")
    activities = relationship("Activity", back_populates="case", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="case", cascade="all, delete-orphan")
EOF

cat > app/models/stage.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Stage(Base):
    __tablename__ = "stages"
    __table_args__ = (Index("ix_stages_case_id", "case_id"),)
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"))
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    assigned_to: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="pending")
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    deadline: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    completed_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    case = relationship("Case", back_populates="stages")
    assigned_user = relationship("User", foreign_keys=[assigned_to])
EOF

cat > app/models/document.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Document(Base):
    __tablename__ = "documents"
    __table_args__ = (Index("ix_documents_case_id", "case_id"), Index("ix_documents_uploaded_by", "uploaded_by"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"))
    name: Mapped[str] = mapped_column(String(500))
    file_path: Mapped[str] = mapped_column(String(1000))
    file_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    uploaded_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_encrypted: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    case = relationship("Case", back_populates="documents")
    uploader = relationship("User", foreign_keys=[uploaded_by])
EOF

cat > app/models/user.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base
from datetime import datetime, timezone

class User(Base):
    __tablename__ = "users"
    __table_args__ = (Index("ix_users_login", "login"), Index("ix_users_role", "role"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(255))
    login: Mapped[str] = mapped_column(String(100), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(50), default="lawyer")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    login_attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    force_password_change: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
EOF

cat > app/models/activity.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Text, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Activity(Base):
    __tablename__ = "activities"
    __table_args__ = (Index("ix_activities_case_id", "case_id"), Index("ix_activities_user_id", "user_id"))
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"))
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    action: Mapped[str] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    case = relationship("Case", back_populates="activities")
    user = relationship("User", foreign_keys=[user_id])
EOF

cat > app/models/payment.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
from datetime import datetime, timezone

class Payment(Base):
    __tablename__ = "payments"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"))
    amount: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(50), default="pending")
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    paid_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    case = relationship("Case", back_populates="payments")
EOF

cat > app/models/case_template.py << 'EOF'
from sqlalchemy import String, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class CaseTemplate(Base):
    __tablename__ = "case_templates"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255))
    case_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    stages_json: Mapped[str] = mapped_column(String(5000))
EOF

cat > app/api/__init__.py << 'EOF'
EOF

cat > app/api/schemas/__init__.py << 'EOF'
EOF

cat > app/api/schemas/client.py << 'EOF'
from pydantic import BaseModel, Field

class ClientCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    phone: str | None = Field(default=None, pattern=r'^\+?[\d\s\-\(\)]{5,20}$')
    email: str | None = Field(default=None, pattern=r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
    status: str = "active"
    tags: str | None = None
    notes: str | None = None

class ClientUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    status: str | None = None
    tags: str | None = None
    notes: str | None = None
EOF

cat > app/api/schemas/case.py << 'EOF'
from pydantic import BaseModel, Field

class CaseCreate(BaseModel):
    client_id: int
    title: str = Field(min_length=1, max_length=500)
    case_type: str | None = None
    description: str | None = None
    status: str = "new"
    template_id: int | None = None
    parent_case_id: int | None = None
    statute_deadline: str | None = None

class CaseUpdate(BaseModel):
    title: str | None = None
    case_type: str | None = None
    description: str | None = None
    status: str | None = None
    owner_id: int | None = None
    statute_deadline: str | None = None

class CaseTransfer(BaseModel):
    new_owner_id: int
EOF

cat > app/api/schemas/stage.py << 'EOF'
from pydantic import BaseModel, Field

class StageCreate(BaseModel):
    case_id: int
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    assigned_to: int | None = None
    order: int = 0
    deadline: str | None = None

class StageUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    assigned_to: int | None = None
    status: str | None = None
    is_completed: bool | None = None
    order: int | None = None
    deadline: str | None = None
EOF

cat > app/api/schemas/user.py << 'EOF'
from pydantic import BaseModel, Field

class UserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    login: str = Field(min_length=3, max_length=100)
    password: str = Field(min_length=6, max_length=255)
    role: str = "lawyer"

class UserLogin(BaseModel):
    login: str
    password: str

class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6, max_length=255)
EOF

cat > app/api/schemas/payment.py << 'EOF'
from pydantic import BaseModel, Field

class PaymentCreate(BaseModel):
    case_id: int
    amount: int = Field(gt=0)
    description: str | None = None
    status: str = "pending"

class PaymentUpdate(BaseModel):
    amount: int | None = None
    description: str | None = None
    status: str | None = None
EOF

echo "Часть 2 готова"cat > app/repositories/__init__.py << 'EOF'
EOF

cat > app/repositories/client_repo.py << 'EOF'
from sqlalchemy import select, update, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self, status=None, search=None, skip=0, limit=50):
        query = select(Client)
        if status: query = query.where(Client.status == status)
        if search: query = query.where(Client.full_name.ilike(f"%{search}%") | Client.phone.ilike(f"%{search}%"))
        result = await self.session.execute(query.order_by(Client.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())
    async def get_by_id(self, client_id: int) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.id == client_id)); return result.scalar_one_or_none()
    async def get_by_access_code(self, code: str) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.access_code == code)); return result.scalar_one_or_none()
    async def create(self, client: Client) -> Client:
        self.session.add(client); await self.session.flush(); return client
    async def update(self, client_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Client).where(Client.id == client_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, client_id: int) -> bool:
        result = await self.session.execute(delete(Client).where(Client.id == client_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Client)); return result.scalar() or 0
EOF

cat > app/repositories/case_repo.py << 'EOF'
from sqlalchemy import select, update, func, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case import Case
from app.models.activity import Activity
from app.models.document import Document
from app.config import settings
import os

class CaseRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self, client_id=None, status=None, case_type=None, owner_id=None, search=None, skip=0, limit=50):
        query = select(Case).options(selectinload(Case.client), selectinload(Case.owner))
        if client_id: query = query.where(Case.client_id == client_id)
        if status: query = query.where(Case.status == status)
        if case_type: query = query.where(Case.case_type == case_type)
        if owner_id: query = query.where(Case.owner_id == owner_id)
        if search: query = query.where(Case.title.ilike(f"%{search}%"))
        result = await self.session.execute(query.order_by(Case.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())
    async def get_by_id(self, case_id: int) -> Case | None:
        result = await self.session.execute(select(Case).options(selectinload(Case.client), selectinload(Case.owner), selectinload(Case.stages), selectinload(Case.documents), selectinload(Case.payments), selectinload(Case.activities).selectinload(Activity.user)).where(Case.id == case_id))
        return result.scalar_one_or_none()
    async def create(self, case: Case) -> Case:
        self.session.add(case); await self.session.flush(); return case
    async def update(self, case_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Case).where(Case.id == case_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, case_id: int) -> bool:
        docs = await self.session.execute(select(Document).where(Document.case_id == case_id))
        for d in docs.scalars().all():
            filepath = d.file_path if d.file_path.startswith("/") else os.path.join(settings.UPLOAD_DIR, d.file_path)
            try:
                if os.path.exists(filepath): os.remove(filepath)
            except OSError:
                pass
        result = await self.session.execute(delete(Case).where(Case.id == case_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Case)); return result.scalar() or 0
    async def get_status_counts(self) -> dict:
        result = await self.session.execute(select(Case.status, func.count(Case.id)).group_by(Case.status))
        return {row[0]: row[1] for row in result.all()}
    async def get_owner_stats(self) -> list:
        from app.models.user import User
        result = await self.session.execute(select(Case.owner_id, User.full_name, func.count(Case.id)).join(User, Case.owner_id == User.id).group_by(Case.owner_id))
        return [{"owner_id": r[0], "full_name": r[1], "total": r[2]} for r in result.all()]
EOF

cat > app/repositories/stage_repo.py << 'EOF'
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.stage import Stage

class StageRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_by_case(self, case_id: int) -> list[Stage]:
        result = await self.session.execute(select(Stage).where(Stage.case_id == case_id).order_by(Stage.order)); return list(result.scalars().all())
    async def create(self, stage: Stage) -> Stage:
        self.session.add(stage); await self.session.flush(); return stage
    async def update(self, stage_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Stage).where(Stage.id == stage_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, stage_id: int) -> bool:
        result = await self.session.execute(delete(Stage).where(Stage.id == stage_id))
        await self.session.flush(); return result.rowcount > 0
EOF

cat > app/repositories/document_repo.py << 'EOF'
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.document import Document

class DocumentRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_by_id(self, doc_id: int) -> Document | None:
        result = await self.session.execute(select(Document).where(Document.id == doc_id)); return result.scalar_one_or_none()
    async def get_by_case(self, case_id: int) -> list[Document]:
        result = await self.session.execute(select(Document).where(Document.case_id == case_id).order_by(Document.created_at.desc()))
        return list(result.scalars().all())
    async def create(self, doc: Document) -> Document:
        self.session.add(doc); await self.session.flush(); return doc
    async def delete(self, doc_id: int) -> bool:
        result = await self.session.execute(delete(Document).where(Document.id == doc_id))
        await self.session.flush(); return result.rowcount > 0
EOF

cat > app/repositories/user_repo.py << 'EOF'
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User

class UserRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self) -> list[User]:
        result = await self.session.execute(select(User).where(User.is_active == True)); return list(result.scalars().all())
    async def get_by_id(self, user_id: int) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id)); return result.scalar_one_or_none()
    async def get_by_login(self, login: str) -> User | None:
        result = await self.session.execute(select(User).where(User.login == login)); return result.scalar_one_or_none()
    async def create(self, user: User) -> User:
        self.session.add(user); await self.session.flush(); return user
    async def update(self, user_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(User).where(User.id == user_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
EOF

cat > app/repositories/activity_repo.py << 'EOF'
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.activity import Activity

class ActivityRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_by_case(self, case_id: int) -> list[Activity]:
        result = await self.session.execute(select(Activity).where(Activity.case_id == case_id).order_by(Activity.created_at.desc()))
        return list(result.scalars().all())
    async def create(self, activity: Activity) -> Activity:
        self.session.add(activity); await self.session.flush(); return activity
EOF

cat > app/repositories/payment_repo.py << 'EOF'
from sqlalchemy import select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.payment import Payment

class PaymentRepository:
    def __init__(self, session: AsyncSession): self.session = session
    async def get_all(self):
        result = await self.session.execute(select(Payment).order_by(Payment.created_at.desc()).limit(100)); return list(result.scalars().all())
    async def get_by_case(self, case_id: int):
        result = await self.session.execute(select(Payment).where(Payment.case_id == case_id).order_by(Payment.created_at.desc()))
        return list(result.scalars().all())
    async def create(self, payment: Payment) -> Payment:
        self.session.add(payment); await self.session.flush(); return payment
    async def update(self, payment_id: int, **kwargs) -> bool:
        result = await self.session.execute(update(Payment).where(Payment.id == payment_id).values(**kwargs))
        await self.session.flush(); return result.rowcount > 0
    async def delete(self, payment_id: int) -> bool:
        result = await self.session.execute(delete(Payment).where(Payment.id == payment_id))
        await self.session.flush(); return result.rowcount > 0
    async def get_total_revenue(self) -> int:
        result = await self.session.execute(select(func.sum(Payment.amount)).where(Payment.status == "paid"))
        return result.scalar() or 0
EOF

cat > app/repositories/case_template_repo.py << 'EOF'
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case_template import CaseTemplate

class CaseTemplateRepository:
    def __init__(self, session: AsyncSession): self.session = sessiona
    async def get_all(self):
        result = await self.session.execute(select(CaseTemplate).order_by(CaseTemplate.name)); return list(result.scalars().all())
    async def get_by_id(self, template_id: int) -> CaseTemplate | None:
        result = await self.session.execute(select(CaseTemplate).where(CaseTemplate.id == template_id))
        return result.scalar_one_or_none()
    async def create(self, template: CaseTemplate) -> CaseTemplate:
        self.session.add(template); await self.session.flush(); return template
    async def delete(self, template_id: int) -> bool:
        result = await self.session.execute(delete(CaseTemplate).where(CaseTemplate.id == template_id))
        await self.session.flush(); return result.rowcount > 0
EOF

echo "Часть 3 готова"cat > app/api/routes/__init__.py << 'EOF'
EOF

cat > app/api/routes/auth.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Response, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.user_repo import UserRepository
from app.api.schemas.user import UserLogin, PasswordChange
from app.core.security import verify_password, create_token, hash_password, generate_csrf_token
from app.core.auth_middleware import get_current_user
from app.config import settings
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/api", tags=["auth"])

@router.post("/auth/login")
async def login(data: UserLogin, response: Response, request: Request, session: AsyncSession = Depends(get_session)):
    repo = UserRepository(session); user = await repo.get_by_login(data.login)
    if not user: raise HTTPException(404, detail="Пользователь не найден")
    if user.locked_until and user.locked_until > datetime.now(timezone.utc): raise HTTPException(423)
    if not verify_password(data.password, user.password_hash):
        attempts = (user.login_attempts or 0) + 1; locked = None
        if attempts >= settings.LOGIN_MAX_ATTEMPTS: locked = datetime.now(timezone.utc) + timedelta(minutes=settings.LOGIN_TIMEOUT_MINUTES)
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
EOF

cat > app/api/routes/clients.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.api.schemas.client import ClientCreate, ClientUpdate
from app.models.client import Client
from app.core.auth_middleware import get_current_user
import openpyxl, io
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/api", tags=["clients"])

@router.get("/clients")
async def get_clients(request: Request, status=None, search=None, skip=0, limit=50, session=Depends(get_session), user=Depends(get_current_user)):
    clients = await ClientRepository(session).get_all(status=status, search=search, skip=skip, limit=limit)
    return [{"id": c.id, "full_name": c.full_name, "phone": c.phone, "email": c.email, "status": c.status, "tags": c.tags, "notes": c.notes, "access_code": c.access_code} for c in clients]

@router.get("/clients/{client_id}")
async def get_client(client_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    c = await ClientRepository(session).get_by_id(client_id)
    if not c: raise HTTPException(404)
    return {"id": c.id, "full_name": c.full_name, "phone": c.phone, "email": c.email, "status": c.status, "tags": c.tags, "notes": c.notes, "access_code": c.access_code}

@router.post("/clients")
async def create_client(data: ClientCreate, session=Depends(get_session), user=Depends(get_current_user)):
    c = Client(full_name=data.full_name, phone=data.phone, email=data.email, status=data.status, tags=data.tags, notes=data.notes)
    result = await ClientRepository(session).create(c); await session.commit(); return {"ok": True, "id": result.id}

@router.put("/clients/{client_id}")
async def update_client(client_id: int, data: ClientUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    ok = await ClientRepository(session).update(client_id, **updates)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.delete("/clients/{client_id}")
async def delete_client(client_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    ok = await ClientRepository(session).delete(client_id)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.get("/clients/export/excel")
async def export_clients(session=Depends(get_session), user=Depends(get_current_user)):
    clients = await ClientRepository(session).get_all()
    wb = openpyxl.Workbook(); ws = wb.active; ws.title = "Клиенты"
    ws.append(["ID", "ФИО", "Телефон", "Email", "Статус", "Теги", "Заметки"])
    for c in clients: ws.append([c.id, c.full_name, c.phone, c.email, c.status, c.tags, c.notes])
    buf = io.BytesIO(); wb.save(buf); buf.seek(0)
    return StreamingResponse(buf, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": "attachment; filename=clients.xlsx"})

@router.post("/clients/import/excel")
async def import_clients(file: UploadFile, session=Depends(get_session), user=Depends(get_current_user)):
    content = await file.read(); wb = openpyxl.load_workbook(io.BytesIO(content)); ws = wb.active; count = 0
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[1]:
            c = Client(full_name=str(row[1]), phone=str(row[2] or ""), email=str(row[3] or ""), status=str(row[4] or "active"))
            await ClientRepository(session).create(c); count += 1
    await session.commit(); return {"ok": True, "imported": count}
EOF

cat > app/api/routes/cases.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository, ActivityRepository, CaseTemplateRepository, StageRepository
from app.api.schemas.case import CaseCreate, CaseUpdate, CaseTransfer
from app.models.case import Case
from app.models.activity import Activity
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user
from datetime import datetime, timezone
import json

router = APIRouter(prefix="/api", tags=["cases"])

@router.get("/cases")
async def get_cases(request: Request, client_id=None, status=None, case_type=None, search=None, skip=0, limit=50, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); owner_id = user["user_id"] if user["role"] != "admin" else None
    cases = await repo.get_all(client_id=client_id, status=status, case_type=case_type, owner_id=owner_id, search=search, skip=skip, limit=limit)
    return [{"id": c.id, "title": c.title, "case_type": c.case_type, "status": c.status, "client_name": c.client.full_name if c.client else "—", "owner_name": c.owner.full_name if c.owner else "—"} for c in cases]

@router.get("/cases/{case_id}")
async def get_case(case_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    return {"id": case.id, "title": case.title, "case_type": case.case_type, "status": case.status, "description": case.description, "statute_deadline": case.statute_deadline.isoformat() if case.statute_deadline else None, "parent_case_id": case.parent_case_id, "client": {"id": case.client.id, "full_name": case.client.full_name} if case.client else None, "owner": {"id": case.owner.id, "full_name": case.owner.full_name} if case.owner else None, "stages": [{"id": s.id, "name": s.name, "status": s.status, "is_completed": s.is_completed} for s in case.stages], "documents": [{"id": d.id, "name": d.name, "file_path": f"/api/documents/{d.id}/download"} for d in case.documents], "payments": [{"id": p.id, "amount": p.amount, "status": p.status, "description": p.description} for p in case.payments], "activities": [{"id": a.id, "action": a.action, "description": a.description, "user_name": a.user.full_name if a.user else "—"} for a in case.activities]}

@router.post("/cases")
async def create_case(data: CaseCreate, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); statute = None
    if data.statute_deadline:
        statute = datetime.fromisoformat(data.statute_deadline).replace(tzinfo=timezone.utc)
    case = Case(client_id=data.client_id, title=data.title, case_type=data.case_type, description=data.description, status=data.status, owner_id=user["user_id"], parent_case_id=data.parent_case_id, statute_deadline=statute)
    result = await repo.create(case)
    if data.template_id:
        tmpl = await CaseTemplateRepository(session).get_by_id(data.template_id)
        if tmpl:
            stages_data = json.loads(tmpl.stages_json); sr = StageRepository(session)
            for i, s in enumerate(stages_data):
                await sr.create(Stage(case_id=result.id, name=s["name"], description=s.get("description",""), order=i, assigned_to=user["user_id"]))
    await ActivityRepository(session).create(Activity(case_id=result.id, user_id=user["user_id"], action="create", description="Дело создано"))
    await session.commit(); return {"ok": True, "id": result.id}

@router.put("/cases/{case_id}")
async def update_case(case_id: int, data: CaseUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    updates = {k: v for k, v in data.model_dump().items() if v is not None and k != "statute_deadline"}
    if data.statute_deadline:
        updates["statute_deadline"] = datetime.fromisoformat(data.statute_deadline).replace(tzinfo=timezone.utc)
    ok = await repo.update(case_id, **updates)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="update", description=str(updates)[:500]))
    await session.commit(); return {"ok": True}

@router.post("/cases/{case_id}/transfer")
async def transfer_case(case_id: int, data: CaseTransfer, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    await repo.update(case_id, owner_id=data.new_owner_id)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="transfer", description=f"Дело передано пользователю {data.new_owner_id}"))
    await session.commit(); return {"ok": True}

@router.delete("/cases/{case_id}")
async def delete_case(case_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session); case = await repo.get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="delete", description=f"Дело удалено: {case.title}"))
    await repo.delete(case_id); await session.commit(); return {"ok": True}
EOF

cat > app/api/routes/stages.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.stage_repo import StageRepository
from app.api.schemas.stage import StageCreate, StageUpdate
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user
from datetime import datetime, timezone

router = APIRouter(prefix="/api", tags=["stages"])

@router.post("/stages")
async def create_stage(data: StageCreate, session=Depends(get_session), user=Depends(get_current_user)):
    deadline = None
    if data.deadline:
        deadline = datetime.fromisoformat(data.deadline).replace(tzinfo=timezone.utc)
    stage = Stage(case_id=data.case_id, name=data.name, description=data.description, assigned_to=data.assigned_to, order=data.order, deadline=deadline)
    result = await StageRepository(session).create(stage); await session.commit(); return {"ok": True, "id": result.id}

@router.put("/stages/{stage_id}")
async def update_stage(stage_id: int, data: StageUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    updates = {k: v for k, v in data.model_dump().items() if v is not None and k != "deadline"}
    if data.deadline:
        updates["deadline"] = datetime.fromisoformat(data.deadline).replace(tzinfo=timezone.utc)
    ok = await StageRepository(session).update(stage_id, **updates)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.delete("/stages/{stage_id}")
async def delete_stage(stage_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    ok = await StageRepository(session).delete(stage_id)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}
EOF

cat > app/api/routes/documents.py << 'EOF'
import uuid, os, aiofiles, magic
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks
from fastapi.responses import FileResponse as FastFileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.document_repo import DocumentRepository
from app.repositories.case_repo import CaseRepository
from app.models.document import Document
from app.config import settings
from app.core.auth_middleware import get_current_user
from app.core.security import encrypt_file, decrypt_file

router = APIRouter(prefix="/api", tags=["documents"])
ALLOWED_MIMES = {"application/pdf", "image/jpeg", "image/png", "image/jpg", "image/webp", "image/gif"}

@router.post("/documents/upload")
async def upload_document(case_id: int = Form(...), file: UploadFile = File(...), session=Depends(get_session), user=Depends(get_current_user)):
    case = await CaseRepository(session).get_by_id(case_id)
    if not case: raise HTTPException(404)
    if user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    content = await file.read()
    if len(content) > settings.MAX_FILE_SIZE_MB * 1024 * 1024: raise HTTPException(400)
    detected = magic.from_buffer(content[:2048], mime=True)
    if detected not in ALLOWED_MIMES: raise HTTPException(400)
    ext = os.path.splitext(file.filename or "file")[1]; filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = settings.UPLOAD_DIR; os.makedirs(upload_dir, exist_ok=True); filepath = os.path.join(upload_dir, filename)
    async with aiofiles.open(filepath, "wb") as f: await f.write(encrypt_file(content))
    doc = Document(case_id=case_id, name=file.filename or "file", file_path=f"/static/uploads/{filename}", file_type=detected, uploaded_by=user["user_id"], is_encrypted=True)
    result = await DocumentRepository(session).create(doc); await session.commit()
    return {"ok": True, "id": result.id, "path": f"/api/documents/{result.id}/download"}

@router.get("/documents/{doc_id}/download")
async def download_document(doc_id: int, background_tasks: BackgroundTasks, session=Depends(get_session), user=Depends(get_current_user)):
    doc = await DocumentRepository(session).get_by_id(doc_id)
    if not doc: raise HTTPException(404)
    case = await CaseRepository(session).get_by_id(doc.case_id)
    if case and user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    filepath = doc.file_path if doc.file_path.startswith("/") else os.path.join(settings.UPLOAD_DIR, doc.file_path)
    if not os.path.exists(filepath): raise HTTPException(404)
    temp_path = filepath + f".{uuid.uuid4().hex}.tmp"
    async with aiofiles.open(filepath, "rb") as src: encrypted = await src.read()
    async with aiofiles.open(temp_path, "wb") as dst: await dst.write(decrypt_file(encrypted))
    background_tasks.add_task(os.remove, temp_path)
    return FastFileResponse(temp_path, filename=doc.name)

@router.delete("/documents/{doc_id}")
async def delete_document(doc_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    doc = await DocumentRepository(session).get_by_id(doc_id)
    if not doc: raise HTTPException(404)
    case = await CaseRepository(session).get_by_id(doc.case_id)
    if case and user["role"] != "admin" and case.owner_id != user["user_id"]: raise HTTPException(403)
    filepath = doc.file_path if doc.file_path.startswith("/") else os.path.join(settings.UPLOAD_DIR, doc.file_path)
    if os.path.exists(filepath): os.remove(filepath)
    await DocumentRepository(session).delete(doc_id); await session.commit(); return {"ok": True}
EOF

cat > app/api/routes/users.py << 'EOF'
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
EOF

cat > app/api/routes/dashboard.py << 'EOF'
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
EOF

cat > app/api/routes/finance.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.payment_repo import PaymentRepository
from app.api.schemas.payment import PaymentCreate, PaymentUpdate
from app.models.payment import Payment
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["finance"])

@router.get("/payments")
async def get_payments(session=Depends(get_session), user=Depends(get_current_user)):
    return [{"id": p.id, "case_id": p.case_id, "amount": p.amount, "status": p.status, "description": p.description, "created_at": p.created_at.isoformat() if p.created_at else None} for p in await PaymentRepository(session).get_all()]

@router.post("/payments")
async def create_payment(data: PaymentCreate, session=Depends(get_session), user=Depends(get_current_user)):
    p = Payment(case_id=data.case_id, amount=data.amount, description=data.description, status=data.status)
    result = await PaymentRepository(session).create(p); await session.commit(); return {"ok": True, "id": result.id}

@router.put("/payments/{payment_id}")
async def update_payment(payment_id: int, data: PaymentUpdate, session=Depends(get_session), user=Depends(get_current_user)):
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    ok = await PaymentRepository(session).update(payment_id, **updates)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.delete("/payments/{payment_id}")
async def delete_payment(payment_id: int, session=Depends(get_session), user=Depends(get_current_user)):
    ok = await PaymentRepository(session).delete(payment_id)
    if not ok: raise HTTPException(404)
    await session.commit(); return {"ok": True}

@router.get("/finance/stats")
async def get_finance_stats(session=Depends(get_session), user=Depends(get_current_user)):
    return {"total_revenue": await PaymentRepository(session).get_total_revenue()}
EOF

cat > app/api/routes/reports.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["reports"])

@router.get("/reports/lawyers")
async def get_lawyer_report(session=Depends(get_session), user=Depends(get_current_user)):
    return await CaseRepository(session).get_owner_stats()
EOF

cat > app/api/routes/client_portal.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.case_repo import CaseRepository
from datetime import datetime, timezone

router = APIRouter(prefix="/api", tags=["portal"])

@router.get("/portal/{access_code}")
async def get_client_portal(access_code: str, session=Depends(get_session)):
    client = await ClientRepository(session).get_by_access_code(access_code)
    if not client: raise HTTPException(404)
    if client.access_code_expiry and client.access_code_expiry < datetime.now(timezone.utc):
        raise HTTPException(410, detail="Срок действия ссылки истёк")
    cases = await CaseRepository(session).get_all(client_id=client.id)
    return {"client": {"id": client.id, "full_name": client.full_name}, "cases": [{"id": c.id, "title": c.title, "status": c.status, "case_type": c.case_type, "description": c.description} for c in cases]}
EOF

cat > app/api/routes/templates.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_template_repo import CaseTemplateRepository
from app.models.case_template import CaseTemplate
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["templates"])

@router.get("/templates")
async def get_templates(session=Depends(get_session), user=Depends(get_current_user)):
    return [{"id": t.id, "name": t.name, "case_type": t.case_type} for t in await CaseTemplateRepository(session).get_all()]

@router.post("/templates")
async def create_template(data: dict, session=Depends(get_session), user=Depends(get_current_user)):
    t = CaseTemplate(name=data["name"], case_type=data.get("case_type"), stages_json=data.get("stages_json","[]"))
    result = await CaseTemplateRepository(session).create(t); await session.commit(); return {"ok": True, "id": result.id}
EOF

echo "Часть 4 готова"cat > app/static/admin.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM Юрист v6.3</title>
    <link rel="manifest" href="/static/manifest.json">
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        :root{--bg:#f0f2f5;--card:#fff;--text:#1a1a2e;--sidebar:#1a1a2e;--accent:#c9a96e;--danger:#c0392b;--success:#27ae60}
        body.dark{--bg:#0d0d0d;--card:#1a1a1a;--text:#f5f5f5;--sidebar:#111}
        body{font-family:'Segoe UI',sans-serif;background:var(--bg);color:var(--text)}
        .login-overlay{display:flex;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.6);justify-content:center;align-items:center;z-index:9999}
        .login-box{background:var(--card);padding:40px;border-radius:16px;width:90%;max-width:420px;text-align:center}
        .login-box h2{margin-bottom:24px}
        .login-box input{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:8px;font-size:16px;background:var(--bg);color:var(--text)}
        .login-box button{width:100%;padding:14px;background:var(--accent);color:#1a1a2e;border:none;border-radius:8px;font-size:16px;font-weight:600;cursor:pointer;margin-top:8px}
        .login-error{color:var(--danger);font-size:14px;margin-top:8px}
        .app-layout{display:flex;min-height:100vh}
        .sidebar{width:240px;background:var(--sidebar);color:white;padding:20px;display:flex;flex-direction:column;gap:8px}
        .sidebar h2{color:var(--accent);margin-bottom:16px;font-size:20px}
        .sidebar a{color:white;text-decoration:none;padding:12px 16px;border-radius:8px;display:block;font-size:14px;cursor:pointer}
        .sidebar a:hover{background:#2a2a4e}
        .sidebar a.active{background:var(--accent);color:#1a1a2e;font-weight:600}
        .main{flex:1;padding:30px;overflow-y:auto}
        .header{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}
        .header h1{font-size:24px}
        .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}
        .stat-card{background:var(--card);padding:20px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        .stat-card .value{font-size:32px;font-weight:700;color:var(--accent)}
        .stat-card .label{color:#888;font-size:14px;margin-top:4px}
        table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        th{background:var(--sidebar);color:white;padding:12px 16px;text-align:left;font-weight:600}
        td{padding:12px 16px;border-bottom:1px solid #eee}
        tr:hover{background:var(--bg)}
        .btn{padding:8px 16px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:600;margin:2px}
        .btn-primary{background:var(--sidebar);color:white}
        .btn-success{background:var(--success);color:white}
        .btn-danger{background:var(--danger);color:white}
        .badge{padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
        .badge-active{background:var(--success);color:white}
        .badge-new{background:#3498db;color:white}
        .badge-closed{background:#888;color:white}
        .modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);justify-content:center;align-items:center;z-index:1000}
        .modal.active{display:flex}
        .modal-content{background:var(--card);padding:30px;border-radius:12px;width:90%;max-width:500px;max-height:80vh;overflow-y:auto;color:var(--text)}
        .form-group{margin-bottom:16px}
        .form-group label{display:block;font-weight:600;margin-bottom:4px;font-size:14px}
        .form-group input,.form-group select,.form-group textarea{width:100%;padding:10px;border:1px solid #ddd;border-radius:8px;font-size:15px;background:var(--bg);color:var(--text)}
        .form-group textarea{min-height:80px;resize:vertical}
        .form-actions{display:flex;gap:10px;justify-content:flex-end;margin-top:20px}
        .logout-btn{background:var(--danger);color:white;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-weight:600}
        .theme-toggle{background:transparent;border:1px solid var(--accent);color:var(--accent);padding:6px 12px;border-radius:6px;cursor:pointer;font-size:12px}
        @media(max-width:768px){.sidebar{display:none}.stats{grid-template-columns:repeat(2,1fr)}}
    </style>
</head>
<body>
<div class="login-overlay" id="loginOverlay"><div class="login-box"><h2>⚖️ CRM Юрист</h2><input type="text" id="loginInput" placeholder="Логин"><input type="password" id="passInput" placeholder="Пароль"><button onclick="App.doLogin()">Войти</button><div class="login-error" id="loginError"></div></div></div>
<div class="app-layout" id="appLayout" style="display:none"><div class="sidebar" id="sidebar"></div><div class="main" id="content"><div class="header"><h1>📊 Дашборд</h1><button class="theme-toggle" onclick="App.toggleTheme()">🌓 Тема</button></div><div class="stats" id="stats"></div><div id="table-container"></div></div></div>
<div class="modal" id="modal"><div class="modal-content" id="modal-content"></div></div>
<script src="/static/js/app.js"></script>
<script src="/static/js/modules/dashboard.js"></script>
<script src="/static/js/modules/clients.js"></script>
<script src="/static/js/modules/cases.js"></script>
<script src="/static/js/modules/users.js"></script>
<script src="/static/js/modules/finance.js"></script>
</body>
</html>
EOF

cat > app/static/client.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Личный кабинет клиента</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',sans-serif;background:#f0f2f5;color:#1a1a2e;padding:40px 20px;max-width:800px;margin:0 auto}
        h1{color:#1a1a2e;margin-bottom:24px;font-size:clamp(20px,5vw,28px)}
        .card{background:white;padding:20px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08);margin-bottom:16px}
        .card h2{color:#c9a96e;margin-bottom:8px}
        .badge{padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600;display:inline-block}
        .badge-active{background:#27ae60;color:white}.badge-new{background:#3498db;color:white}.badge-closed{background:#888;color:white}
        .error{color:#c0392b;text-align:center;margin-top:40px}
    </style>
</head>
<body><h1>⚖️ Личный кабинет</h1><div id="content"></div>
<script>
const code = window.location.pathname.split('/').pop();
fetch('/api/portal/'+code).then(r=>r.json()).then(data=>{
    if(data.detail){document.getElementById('content').innerHTML='<div class="error">'+data.detail+'</div>';return}
    let html=`<div class="card"><h2>${data.client.full_name}</h2><p>Ваши дела:</p></div>`;
    data.cases.forEach(c=>{html+=`<div class="card"><h2>${c.title}</h2><p>Тип: ${c.case_type||'—'} | Статус: <span class="badge badge-${c.status==='new'?'new':c.status==='active'?'active':'closed'}">${c.status}</span></p>${c.description?`<p>${c.description}</p>`:''}</div>`});
    document.getElementById('content').innerHTML=html;
});
</script>
</body>
</html>
EOF

cat > app/static/manifest.json << 'EOF'
{"name":"CRM Юрист","short_name":"CRM","start_url":"/admin","display":"standalone","background_color":"#1a1a2e","theme_color":"#c9a96e","icons":[{"src":"/static/icon-192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icon-512.png","sizes":"512x512","type":"image/png"}]}
EOF

cat > app/static/sw.js << 'EOF'
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('fetch', e => e.respondWith(fetch(e.request).catch(() => caches.match(e.request))));
EOF

cat > app/static/js/app.js << 'EOF'
const App = {
    csrfToken: '', user: null, currentTab: 'dashboard',
    async api(url, options = {}) {
        const headers = { ...options.headers, 'X-CSRF-Token': App.csrfToken };
        const res = await fetch(url, { ...options, headers, credentials: 'include' });
        if (res.status === 401) { App.logout(); throw new Error('Unauthorized'); }
        if (res.status === 423) { alert('Аккаунт заблокирован.'); throw new Error('Locked'); }
        if (res.status === 500) { alert('Ошибка сервера. Попробуйте позже.'); throw new Error('ServerError'); }
        if (!res.ok) { const d = await res.json().catch(()=>({})); throw new Error(d.detail || 'Ошибка'); }
        return res.json();
    },
    async doLogin() {
        const login = document.getElementById('loginInput').value, password = document.getElementById('passInput').value;
        document.getElementById('loginError').textContent = '';
        try {
            const res = await fetch('/api/auth/login', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({login,password})});
            const data = await res.json();
            if (data.ok) {
                App.csrfToken = data.csrf_token; App.user = data.user;
                document.getElementById('loginOverlay').style.display = 'none';
                document.getElementById('appLayout').style.display = 'flex';
                App.renderSidebar();
                if (data.user.force_password_change) App.showPasswordChange(); else App.showTab('dashboard');
            } else { document.getElementById('loginError').textContent = data.detail || 'Ошибка входа'; }
        } catch (e) { document.getElementById('loginError').textContent = 'Ошибка соединения'; }
    },
    async logout() { await fetch('/api/auth/logout', {method:'POST',credentials:'include'}); App.csrfToken=''; App.user=null; document.getElementById('loginOverlay').style.display='flex'; document.getElementById('appLayout').style.display='none'; },
    showPasswordChange() {
        document.getElementById('modal').classList.add('active');
        document.getElementById('modal-content').innerHTML = `<h2>Смена пароля</h2><p style="color:var(--danger);margin-bottom:16px">Перед началом работы необходимо сменить пароль.</p><div class="form-group"><label>Старый пароль</label><input id="oldpw" type="password" value="admin123"></div><div class="form-group"><label>Новый пароль (мин. 6 символов)</label><input id="newpw" type="password" minlength="6"></div><div class="form-group"><label>Повторите пароль</label><input id="newpw2" type="password" minlength="6"></div><button class="btn btn-success" style="width:100%" onclick="App.changePassword()">Сменить</button><div class="login-error" id="pwError" style="margin-top:12px"></div>`;
    },
    async changePassword() {
        const old=document.getElementById('oldpw').value, n1=document.getElementById('newpw').value, n2=document.getElementById('newpw2').value;
        if (n1.length<6) { document.getElementById('pwError').textContent='Пароль должен быть не менее 6 символов'; return; }
        if (n1!==n2) { document.getElementById('pwError').textContent='Пароли не совпадают'; return; }
        const res = await App.api('/api/auth/change-password', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({old_password:old,new_password:n1})});
        if (res.ok) { App.closeModal(); App.user.force_password_change=false; App.showTab('dashboard'); alert('Пароль изменён!'); }
    },
    renderSidebar() {
        const menu = [{id:'dashboard',icon:'📊',label:'Дашборд'},{id:'clients',icon:'👥',label:'Клиенты'},{id:'cases',icon:'📁',label:'Дела'},{id:'users',icon:'👨‍💼',label:'Сотрудники',admin:true},{id:'finance',icon:'💰',label:'Финансы',admin:true}];
        let html = '<h2>⚖️ CRM Юрист</h2>';
        menu.forEach(item => { if (item.admin && App.user?.role !== 'admin') return; html += `<a class="${App.currentTab===item.id?'active':''}" onclick="App.showTab('${item.id}')">${item.icon} ${item.label}</a>`; });
        html += '<button class="logout-btn" onclick="App.logout()" style="margin-top:auto">🚪 Выйти</button>';
        document.getElementById('sidebar').innerHTML = html;
    },
    async showTab(tab) { App.currentTab=tab; App.renderSidebar(); document.getElementById('table-container').innerHTML=''; const fn=window[tab]?.load||DashboardModule.load; await fn(); },
    toggleTheme() { document.body.classList.toggle('dark'); localStorage.setItem('crm_theme', document.body.classList.contains('dark')?'dark':'light'); },
    closeModal() { document.getElementById('modal').classList.remove('active'); },
    text(str) { const div=document.createElement('div'); div.appendChild(document.createTextNode(str||'')); return div.innerHTML; }
};
if (localStorage.getItem('crm_theme')==='dark') document.body.classList.add('dark');
EOF

echo "Часть 5 готова"cat > app/static/admin.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM Юрист v6.3</title>
    <link rel="manifest" href="/static/manifest.json">
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        :root{--bg:#f0f2f5;--card:#fff;--text:#1a1a2e;--sidebar:#1a1a2e;--accent:#c9a96e;--danger:#c0392b;--success:#27ae60}
        body.dark{--bg:#0d0d0d;--card:#1a1a1a;--text:#f5f5f5;--sidebar:#111}
        body{font-family:'Segoe UI',sans-serif;background:var(--bg);color:var(--text)}
        .login-overlay{display:flex;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.6);justify-content:center;align-items:center;z-index:9999}
        .login-box{background:var(--card);padding:40px;border-radius:16px;width:90%;max-width:420px;text-align:center}
        .login-box h2{margin-bottom:24px}
        .login-box input{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:8px;font-size:16px;background:var(--bg);color:var(--text)}
        .login-box button{width:100%;padding:14px;background:var(--accent);color:#1a1a2e;border:none;border-radius:8px;font-size:16px;font-weight:600;cursor:pointer;margin-top:8px}
        .login-error{color:var(--danger);font-size:14px;margin-top:8px}
        .app-layout{display:flex;min-height:100vh}
        .sidebar{width:240px;background:var(--sidebar);color:white;padding:20px;display:flex;flex-direction:column;gap:8px}
        .sidebar h2{color:var(--accent);margin-bottom:16px;font-size:20px}
        .sidebar a{color:white;text-decoration:none;padding:12px 16px;border-radius:8px;display:block;font-size:14px;cursor:pointer}
        .sidebar a:hover{background:#2a2a4e}
        .sidebar a.active{background:var(--accent);color:#1a1a2e;font-weight:600}
        .main{flex:1;padding:30px;overflow-y:auto}
        .header{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}
        .header h1{font-size:24px}
        .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}
        .stat-card{background:var(--card);padding:20px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        .stat-card .value{font-size:32px;font-weight:700;color:var(--accent)}
        .stat-card .label{color:#888;font-size:14px;margin-top:4px}
        table{width:100%;border-collapse:collapse;background:var(--card);border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        th{background:var(--sidebar);color:white;padding:12px 16px;text-align:left;font-weight:600}
        td{padding:12px 16px;border-bottom:1px solid #eee}
        tr:hover{background:var(--bg)}
        .btn{padding:8px 16px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:600;margin:2px}
        .btn-primary{background:var(--sidebar);color:white}
        .btn-success{background:var(--success);color:white}
        .btn-danger{background:var(--danger);color:white}
        .badge{padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
        .badge-active{background:var(--success);color:white}
        .badge-new{background:#3498db;color:white}
        .badge-closed{background:#888;color:white}
        .modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);justify-content:center;align-items:center;z-index:1000}
        .modal.active{display:flex}
        .modal-content{background:var(--card);padding:30px;border-radius:12px;width:90%;max-width:500px;max-height:80vh;overflow-y:auto;color:var(--text)}
        .form-group{margin-bottom:16px}
        .form-group label{display:block;font-weight:600;margin-bottom:4px;font-size:14px}
        .form-group input,.form-group select,.form-group textarea{width:100%;padding:10px;border:1px solid #ddd;border-radius:8px;font-size:15px;background:var(--bg);color:var(--text)}
        .form-group textarea{min-height:80px;resize:vertical}
        .form-actions{display:flex;gap:10px;justify-content:flex-end;margin-top:20px}
        .logout-btn{background:var(--danger);color:white;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-weight:600}
        .theme-toggle{background:transparent;border:1px solid var(--accent);color:var(--accent);padding:6px 12px;border-radius:6px;cursor:pointer;font-size:12px}
        @media(max-width:768px){.sidebar{display:none}.stats{grid-template-columns:repeat(2,1fr)}}
    </style>
</head>
<body>
<div class="login-overlay" id="loginOverlay"><div class="login-box"><h2>⚖️ CRM Юрист</h2><input type="text" id="loginInput" placeholder="Логин"><input type="password" id="passInput" placeholder="Пароль"><button onclick="App.doLogin()">Войти</button><div class="login-error" id="loginError"></div></div></div>
<div class="app-layout" id="appLayout" style="display:none"><div class="sidebar" id="sidebar"></div><div class="main" id="content"><div class="header"><h1>📊 Дашборд</h1><button class="theme-toggle" onclick="App.toggleTheme()">🌓 Тема</button></div><div class="stats" id="stats"></div><div id="table-container"></div></div></div>
<div class="modal" id="modal"><div class="modal-content" id="modal-content"></div></div>
<script src="/static/js/app.js"></script>
<script src="/static/js/modules/dashboard.js"></script>
<script src="/static/js/modules/clients.js"></script>
<script src="/static/js/modules/cases.js"></script>
<script src="/static/js/modules/users.js"></script>
<script src="/static/js/modules/finance.js"></script>
</body>
</html>
EOF

cat > app/static/client.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Личный кабинет клиента</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',sans-serif;background:#f0f2f5;color:#1a1a2e;padding:40px 20px;max-width:800px;margin:0 auto}
        h1{color:#1a1a2e;margin-bottom:24px;font-size:clamp(20px,5vw,28px)}
        .card{background:white;padding:20px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08);margin-bottom:16px}
        .card h2{color:#c9a96e;margin-bottom:8px}
        .badge{padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600;display:inline-block}
        .badge-active{background:#27ae60;color:white}.badge-new{background:#3498db;color:white}.badge-closed{background:#888;color:white}
        .error{color:#c0392b;text-align:center;margin-top:40px}
    </style>
</head>
<body><h1>⚖️ Личный кабинет</h1><div id="content"></div>
<script>
const code = window.location.pathname.split('/').pop();
fetch('/api/portal/'+code).then(r=>r.json()).then(data=>{
    if(data.detail){document.getElementById('content').innerHTML='<div class="error">'+data.detail+'</div>';return}
    let html=`<div class="card"><h2>${data.client.full_name}</h2><p>Ваши дела:</p></div>`;
    data.cases.forEach(c=>{html+=`<div class="card"><h2>${c.title}</h2><p>Тип: ${c.case_type||'—'} | Статус: <span class="badge badge-${c.status==='new'?'new':c.status==='active'?'active':'closed'}">${c.status}</span></p>${c.description?`<p>${c.description}</p>`:''}</div>`});
    document.getElementById('content').innerHTML=html;
});
</script>
</body>
</html>
EOF

cat > app/static/manifest.json << 'EOF'
{"name":"CRM Юрист","short_name":"CRM","start_url":"/admin","display":"standalone","background_color":"#1a1a2e","theme_color":"#c9a96e","icons":[{"src":"/static/icon-192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icon-512.png","sizes":"512x512","type":"image/png"}]}
EOF

cat > app/static/sw.js << 'EOF'
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('fetch', e => e.respondWith(fetch(e.request).catch(() => caches.match(e.request))));
EOF

cat > app/static/js/app.js << 'EOF'
const App = {
    csrfToken: '', user: null, currentTab: 'dashboard',
    async api(url, options = {}) {
        const headers = { ...options.headers, 'X-CSRF-Token': App.csrfToken };
        const res = await fetch(url, { ...options, headers, credentials: 'include' });
        if (res.status === 401) { App.logout(); throw new Error('Unauthorized'); }
        if (res.status === 423) { alert('Аккаунт заблокирован.'); throw new Error('Locked'); }
        if (res.status === 500) { alert('Ошибка сервера. Попробуйте позже.'); throw new Error('ServerError'); }
        if (!res.ok) { const d = await res.json().catch(()=>({})); throw new Error(d.detail || 'Ошибка'); }
        return res.json();
    },
    async doLogin() {
        const login = document.getElementById('loginInput').value, password = document.getElementById('passInput').value;
        document.getElementById('loginError').textContent = '';
        try {
            const res = await fetch('/api/auth/login', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({login,password})});
            const data = await res.json();
            if (data.ok) {
                App.csrfToken = data.csrf_token; App.user = data.user;
                document.getElementById('loginOverlay').style.display = 'none';
                document.getElementById('appLayout').style.display = 'flex';
                App.renderSidebar();
                if (data.user.force_password_change) App.showPasswordChange(); else App.showTab('dashboard');
            } else { document.getElementById('loginError').textContent = data.detail || 'Ошибка входа'; }
        } catch (e) { document.getElementById('loginError').textContent = 'Ошибка соединения'; }
    },
    async logout() { await fetch('/api/auth/logout', {method:'POST',credentials:'include'}); App.csrfToken=''; App.user=null; document.getElementById('loginOverlay').style.display='flex'; document.getElementById('appLayout').style.display='none'; },
    showPasswordChange() {
        document.getElementById('modal').classList.add('active');
        document.getElementById('modal-content').innerHTML = `<h2>Смена пароля</h2><p style="color:var(--danger);margin-bottom:16px">Перед началом работы необходимо сменить пароль.</p><div class="form-group"><label>Старый пароль</label><input id="oldpw" type="password" value="admin123"></div><div class="form-group"><label>Новый пароль (мин. 6 символов)</label><input id="newpw" type="password" minlength="6"></div><div class="form-group"><label>Повторите пароль</label><input id="newpw2" type="password" minlength="6"></div><button class="btn btn-success" style="width:100%" onclick="App.changePassword()">Сменить</button><div class="login-error" id="pwError" style="margin-top:12px"></div>`;
    },
    async changePassword() {
        const old=document.getElementById('oldpw').value, n1=document.getElementById('newpw').value, n2=document.getElementById('newpw2').value;
        if (n1.length<6) { document.getElementById('pwError').textContent='Пароль должен быть не менее 6 символов'; return; }
        if (n1!==n2) { document.getElementById('pwError').textContent='Пароли не совпадают'; return; }
        const res = await App.api('/api/auth/change-password', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({old_password:old,new_password:n1})});
        if (res.ok) { App.closeModal(); App.user.force_password_change=false; App.showTab('dashboard'); alert('Пароль изменён!'); }
    },
    renderSidebar() {
        const menu = [{id:'dashboard',icon:'📊',label:'Дашборд'},{id:'clients',icon:'👥',label:'Клиенты'},{id:'cases',icon:'📁',label:'Дела'},{id:'users',icon:'👨‍💼',label:'Сотрудники',admin:true},{id:'finance',icon:'💰',label:'Финансы',admin:true}];
        let html = '<h2>⚖️ CRM Юрист</h2>';
        menu.forEach(item => { if (item.admin && App.user?.role !== 'admin') return; html += `<a class="${App.currentTab===item.id?'active':''}" onclick="App.showTab('${item.id}')">${item.icon} ${item.label}</a>`; });
        html += '<button class="logout-btn" onclick="App.logout()" style="margin-top:auto">🚪 Выйти</button>';
        document.getElementById('sidebar').innerHTML = html;
    },
    async showTab(tab) { App.currentTab=tab; App.renderSidebar(); document.getElementById('table-container').innerHTML=''; const fn=window[tab]?.load||DashboardModule.load; await fn(); },
    toggleTheme() { document.body.classList.toggle('dark'); localStorage.setItem('crm_theme', document.body.classList.contains('dark')?'dark':'light'); },
    closeModal() { document.getElementById('modal').classList.remove('active'); },
    text(str) { const div=document.createElement('div'); div.appendChild(document.createTextNode(str||'')); return div.innerHTML; }
};
if (localStorage.getItem('crm_theme')==='dark') document.body.classList.add('dark');
EOF

echo "Часть 5 готова"cat > app/static/js/modules/dashboard.js << 'EOF'
const DashboardModule = {
    async load() {
        document.querySelector('.header h1').textContent = '📊 Дашборд'; document.getElementById('stats').innerHTML = '';
        const stats = await App.api('/api/dashboard/stats');
        document.getElementById('stats').innerHTML = `<div class="stat-card"><div class="value">${stats.total_clients||0}</div><div class="label">Всего клиентов</div></div><div class="stat-card"><div class="value">${stats.total_cases||0}</div><div class="label">Всего дел</div></div><div class="stat-card"><div class="value">${stats.active_cases||0}</div><div class="label">Активных дел</div></div><div class="stat-card"><div class="value">${stats.closed_cases||0}</div><div class="label">Закрытых дел</div></div>`;
    }
};
setInterval(() => { if (App.currentTab === 'dashboard') DashboardModule.load(); }, 60000);
EOF

cat > app/static/js/modules/clients.js << 'EOF'
const clientsModule = {
    async load(search='') {
        document.querySelector('.header h1').textContent = '👥 Клиенты'; document.getElementById('stats').innerHTML = '';
        const url = search ? `/api/clients?search=${encodeURIComponent(search)}` : '/api/clients';
        const data = await App.api(url);
        let html = `<div style="display:flex;gap:10px;margin-bottom:16px"><input type="text" id="searchInput" placeholder="🔍 Поиск..." style="flex:1;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:15px;background:var(--bg);color:var(--text)" value="${search}"><button class="btn btn-primary" onclick="clientsModule.load(document.getElementById('searchInput').value)">🔍</button><button class="btn btn-success" onclick="clientsModule.showForm()">➕</button><button class="btn btn-primary" onclick="clientsModule.exportExcel()">📥 Excel</button></div><table><tr><th>ID</th><th>ФИО</th><th>Телефон</th><th>Email</th><th>Теги</th><th>Статус</th><th></th></tr>`;
        data.forEach(c => { html += `<tr><td>${c.id}</td><td>${App.text(c.full_name)}</td><td>${App.text(c.phone||'—')}</td><td>${App.text(c.email||'—')}</td><td>${App.text(c.tags||'—')}</td><td><span class="badge badge-${c.status==='active'?'active':'closed'}">${c.status}</span></td><td><button class="btn btn-primary" onclick="clientsModule.edit(${c.id})">✏️</button> <button class="btn btn-danger" onclick="clientsModule.del(${c.id})">🗑️</button></td></tr>`; });
        html += '</table>'; document.getElementById('table-container').innerHTML = html;
    },
    async exportExcel() { const res=await fetch('/api/clients/export/excel',{credentials:'include'}); const blob=await res.blob(); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download='clients.xlsx'; a.click(); URL.revokeObjectURL(url); },
    showForm() { document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить клиента</h2><div class="form-group"><label>ФИО</label><input id="cfname"></div><div class="form-group"><label>Телефон</label><input id="cphone"></div><div class="form-group"><label>Email</label><input id="cemail"></div><div class="form-group"><label>Теги</label><input id="ctags"></div><div class="form-group"><label>Заметки</label><textarea id="cnotes"></textarea></div><div class="form-actions"><button class="btn btn-primary" onclick="clientsModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async save() { const data={full_name:document.getElementById('cfname').value,phone:document.getElementById('cphone').value,email:document.getElementById('cemail').value,tags:document.getElementById('ctags').value,notes:document.getElementById('cnotes').value}; await App.api('/api/clients',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); clientsModule.load(); },
    async edit(id) { const c=await App.api('/api/clients/'+id); document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Изменить клиента</h2><div class="form-group"><label>ФИО</label><input id="cfname" value="${c.full_name||''}"></div><div class="form-group"><label>Телефон</label><input id="cphone" value="${c.phone||''}"></div><div class="form-group"><label>Email</label><input id="cemail" value="${c.email||''}"></div><div class="form-group"><label>Теги</label><input id="ctags" value="${c.tags||''}"></div><div class="form-group"><label>Заметки</label><textarea id="cnotes">${c.notes||''}</textarea></div><p style="font-size:12px;color:var(--accent);margin-top:8px">🔗 <span id="clientLink">${window.location.origin}/client/${c.access_code}</span> <button class="btn btn-primary" style="font-size:12px;padding:4px 8px" onclick="clientsModule.copyLink()">📋 Копировать</button></p><div class="form-actions"><button class="btn btn-primary" onclick="clientsModule.update(${id})">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    copyLink() { navigator.clipboard.writeText(document.getElementById('clientLink').textContent).then(()=>alert('Ссылка скопирована!')); },
    async update(id) { const data={full_name:document.getElementById('cfname').value,phone:document.getElementById('cphone').value,email:document.getElementById('cemail').value,tags:document.getElementById('ctags').value,notes:document.getElementById('cnotes').value}; await App.api('/api/clients/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); clientsModule.load(); },
    async del(id) { if(confirm('Удалить?')){await App.api('/api/clients/'+id,{method:'DELETE'}); clientsModule.load();} }
};
EOF

cat > app/static/js/modules/cases.js << 'EOF'
const casesModule = {
    async load(search='') {
        document.querySelector('.header h1').textContent = '📁 Дела'; document.getElementById('stats').innerHTML = '';
        const url = search ? `/api/cases?search=${encodeURIComponent(search)}` : '/api/cases';
        const data = await App.api(url);
        let html = `<div style="display:flex;gap:10px;margin-bottom:16px"><input type="text" id="caseSearch" placeholder="🔍 Поиск по делам..." style="flex:1;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:15px;background:var(--bg);color:var(--text)" value="${search}"><button class="btn btn-primary" onclick="casesModule.load(document.getElementById('caseSearch').value)">🔍</button><button class="btn btn-success" onclick="casesModule.showForm()">➕</button></div><table><tr><th>ID</th><th>Название</th><th>Тип</th><th>Клиент</th><th>Ответственный</th><th>Статус</th><th></th></tr>`;
        data.forEach(c => { html += `<tr><td>${c.id}</td><td><a href="#" onclick="casesModule.view(${c.id})" style="color:#3498db;text-decoration:none">${App.text(c.title)}</a></td><td>${App.text(c.case_type||'—')}</td><td>${App.text(c.client_name||'—')}</td><td>${App.text(c.owner_name||'—')}</td><td><span class="badge badge-${c.status==='new'?'new':c.status==='active'?'active':'closed'}">${c.status}</span></td><td><button class="btn btn-primary" onclick="casesModule.edit(${c.id})">✏️</button> <button class="btn btn-primary" onclick="casesModule.showTransfer(${c.id})">📤</button> <button class="btn btn-danger" onclick="casesModule.del(${c.id})">🗑️</button></td></tr>`; });
        html += '</table>'; document.getElementById('table-container').innerHTML = html;
    },
    showForm() { App.api('/api/templates').then(templates => { let opts = '<option value="">Без шаблона</option>' + templates.map(t => `<option value="${t.id}">${t.name}</option>`).join(''); document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить дело</h2><div class="form-group"><label>Клиент ID</label><input id="cclient" type="number"></div><div class="form-group"><label>Название</label><input id="ctitle"></div><div class="form-group"><label>Тип</label><input id="ctype"></div><div class="form-group"><label>Описание</label><textarea id="cdesc"></textarea></div><div class="form-group"><label>Шаблон этапов</label><select id="ctemplate">${opts}</select></div><div class="form-group"><label>Срок давности</label><input id="cdeadline" type="date"></div><div class="form-actions"><button class="btn btn-primary" onclick="casesModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; }); },
    async save() { const data={client_id:parseInt(document.getElementById('cclient').value),title:document.getElementById('ctitle').value,case_type:document.getElementById('ctype').value,description:document.getElementById('cdesc').value,template_id:parseInt(document.getElementById('ctemplate').value)||null,statute_deadline:document.getElementById('cdeadline').value||null}; await App.api('/api/cases',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); casesModule.load(); },
    async view(id) { const c=await App.api('/api/cases/'+id); document.getElementById('modal').classList.add('active'); let docsHtml=c.documents?.map(d=>{const safePath=(d.file_path||'').startsWith('/api/documents/')?d.file_path:'#';return`<p><a href="${safePath}" target="_blank">📄 ${App.text(d.name)}</a></p>`;}).join('')||'<p>Нет документов</p>'; let payHtml=c.payments?.map(p=>`<p>💰 ${p.amount}₽ — ${p.status} (${p.description||'—'})</p>`).join('')||'<p>Нет платежей</p>'; document.getElementById('modal-content').innerHTML = `<h2>${App.text(c.title)}</h2><p><b>Клиент:</b> ${App.text(c.client?.full_name||'—')} | <b>Статус:</b> ${c.status} | <b>Срок давности:</b> ${c.statute_deadline||'—'}</p><h3>Документы</h3>${docsHtml}<h3>Платежи</h3>${payHtml}<div class="form-actions"><button class="btn btn-danger" onclick="App.closeModal()">Закрыть</button></div>`; },
    async showTransfer(id) { try { const users=await App.api('/api/users'); let opts=users.map(u=>`<option value="${u.id}">${u.full_name}</option>`).join(''); document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Передать дело</h2><div class="form-group"><label>Новый ответственный</label><select id="tuser">${opts}</select></div><div class="form-actions"><button class="btn btn-primary" onclick="casesModule.transfer(${id})">Передать</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; } catch(e) { alert('Нет доступа к списку сотрудников.'); } },
    async transfer(id) { const new_owner_id=parseInt(document.getElementById('tuser').value); await App.api('/api/cases/'+id+'/transfer',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({new_owner_id})}); App.closeModal(); casesModule.load(); },
    async edit(id) { const c=await App.api('/api/cases/'+id); document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Изменить дело</h2><div class="form-group"><label>Название</label><input id="ctitle" value="${c.title||''}"></div><div class="form-group"><label>Тип</label><input id="ctype" value="${c.case_type||''}"></div><div class="form-group"><label>Описание</label><textarea id="cdesc">${c.description||''}</textarea></div><div class="form-group"><label>Статус</label><select id="cstatus"><option value="new" ${c.status==='new'?'selected':''}>Новое</option><option value="active" ${c.status==='active'?'selected':''}>В работе</option><option value="closed" ${c.status==='closed'?'selected':''}>Закрыто</option></select></div><div class="form-actions"><button class="btn btn-primary" onclick="casesModule.update(${id})">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async update(id) { const data={title:document.getElementById('ctitle').value,case_type:document.getElementById('ctype').value,description:document.getElementById('cdesc').value,status:document.getElementById('cstatus').value}; await App.api('/api/cases/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); casesModule.load(); },
    async del(id) { if(confirm('Удалить?')){await App.api('/api/cases/'+id,{method:'DELETE'}); casesModule.load();} }
};
EOF

cat > app/static/js/modules/users.js << 'EOF'
const usersModule = {
    async load() {
        document.querySelector('.header h1').textContent = '👨‍💼 Сотрудники'; document.getElementById('stats').innerHTML = '';
        try {
            const data = await App.api('/api/users');
            let html = '<button class="btn btn-success" onclick="usersModule.showForm()" style="margin-bottom:16px">➕ Добавить</button><table><tr><th>ID</th><th>ФИО</th><th>Логин</th><th>Роль</th></tr>';
            data.forEach(u => { html += `<tr><td>${u.id}</td><td>${App.text(u.full_name)}</td><td>${App.text(u.login)}</td><td>${App.text(u.role)}</td></tr>`; });
            html += '</table>'; document.getElementById('table-container').innerHTML = html;
        } catch (e) { document.getElementById('table-container').innerHTML = '<p style="color:var(--danger)">Нет доступа к списку сотрудников.</p>'; }
    },
    showForm() { document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить сотрудника</h2><div class="form-group"><label>ФИО</label><input id="ufname"></div><div class="form-group"><label>Логин</label><input id="ulogin"></div><div class="form-group"><label>Пароль (мин. 6 символов)</label><input id="upass" type="password" minlength="6"></div><div class="form-group"><label>Роль</label><select id="urole"><option value="lawyer">Юрист</option><option value="admin">Админ</option><option value="secretary">Секретарь</option></select></div><div class="form-actions"><button class="btn btn-primary" onclick="usersModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async save() { const data={full_name:document.getElementById('ufname').value,login:document.getElementById('ulogin').value,password:document.getElementById('upass').value,role:document.getElementById('urole').value}; await App.api('/api/users',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); usersModule.load(); }
};
EOF

cat > app/static/js/modules/finance.js << 'EOF'
const financeModule = {
    paymentsCache: [],
    async load() {
        document.querySelector('.header h1').textContent = '💰 Финансы'; document.getElementById('stats').innerHTML = '';
        try {
            const [payments, stats] = await Promise.all([App.api('/api/payments'), App.api('/api/finance/stats')]);
            financeModule.paymentsCache = payments;
            document.getElementById('stats').innerHTML = `<div class="stat-card"><div class="value">${stats.total_revenue||0}₽</div><div class="label">Общая выручка</div></div>`;
            let html = '<button class="btn btn-success" onclick="financeModule.showForm()" style="margin-bottom:16px">➕ Добавить платёж</button><table><tr><th>ID</th><th>Дело ID</th><th>Сумма</th><th>Статус</th><th>Описание</th><th></th></tr>';
            payments.forEach(p => { html += `<tr><td>${p.id}</td><td>${p.case_id}</td><td>${p.amount}₽</td><td><span class="badge badge-${p.status==='paid'?'active':p.status==='pending'?'new':'closed'}">${p.status}</span></td><td>${App.text(p.description||'—')}</td><td><button class="btn btn-primary" onclick="financeModule.edit(${p.id})">✏️</button> <button class="btn btn-danger" onclick="financeModule.del(${p.id})">🗑️</button></td></tr>`; });
            html += '</table>'; document.getElementById('table-container').innerHTML = html;
        } catch (e) { document.getElementById('table-container').innerHTML = '<p style="color:var(--danger)">Ошибка загрузки финансов.</p>'; }
    },
    showForm() { document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Добавить платёж</h2><div class="form-group"><label>Дело ID</label><input id="pcase" type="number"></div><div class="form-group"><label>Сумма</label><input id="pamount" type="number"></div><div class="form-group"><label>Описание</label><input id="pdesc"></div><div class="form-actions"><button class="btn btn-primary" onclick="financeModule.save()">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async save() { const data={case_id:parseInt(document.getElementById('pcase').value),amount:parseInt(document.getElementById('pamount').value),description:document.getElementById('pdesc').value}; await App.api('/api/payments',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); financeModule.load(); },
    edit(id) { const p=financeModule.paymentsCache.find(x=>x.id===id); if(!p) return; document.getElementById('modal').classList.add('active'); document.getElementById('modal-content').innerHTML = `<h2>Изменить платёж</h2><div class="form-group"><label>Сумма</label><input id="pamount" type="number" value="${p.amount}"></div><div class="form-group"><label>Описание</label><input id="pdesc" value="${p.description||''}"></div><div class="form-group"><label>Статус</label><select id="pstatus"><option value="pending" ${p.status==='pending'?'selected':''}>Ожидает</option><option value="paid" ${p.status==='paid'?'selected':''}>Оплачено</option></select></div><div class="form-actions"><button class="btn btn-primary" onclick="financeModule.update(${id})">Сохранить</button><button class="btn btn-danger" onclick="App.closeModal()">Отмена</button></div>`; },
    async update(id) { const data={amount:parseInt(document.getElementById('pamount').value),description:document.getElementById('pdesc').value,status:document.getElementById('pstatus').value}; await App.api('/api/payments/'+id,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}); App.closeModal(); financeModule.load(); },
    async del(id) { if(confirm('Удалить платёж?')){await App.api('/api/payments/'+id,{method:'DELETE'}); financeModule.load();} }
};
EOF

echo ""
echo "=============================================="
echo "  CRM v6.3.1 — ВСЕ ОШИБКИ ИСПРАВЛЕНЫ"
echo "  Запусти: bash setup.sh"
echo "=============================================="