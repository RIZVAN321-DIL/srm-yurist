#!/bin/bash

mkdir -p app/core app/models app/repositories app/api/routes app/api/schemas app/static/uploads
touch app/static/uploads/.gitkeep

cat > .env << 'ENVEOF'
BOT_TOKEN=ВАШ_ТОКЕН_БОТА
ADMIN_IDS=5724746367
DATABASE_URL=sqlite+aiosqlite:///./crm_yurist.db
API_HOST=0.0.0.0
API_PORT=10000
BASE_URL=https://crm-yurist.onrender.com
SECRET_KEY=crm-yurist-secret-2025
BOT_USERNAME=YuristCRM_bot
JWT_SECRET=crm-jwt-secret-key-2025
JWT_EXPIRE_HOURS=24
MAX_FILE_SIZE_MB=20
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
EOF

cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data /app/app/static/uploads
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
    DATABASE_URL: str = "sqlite+aiosqlite:///./crm_yurist.db"
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
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str):
            return [int(x.strip()) for x in value.split(",") if x.strip()]
        if isinstance(value, list):
            return value
        if isinstance(value, int):
            return [value]
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

class Base(DeclarativeBase):
    pass

engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True, future=True)
async_session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

async def get_session():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
EOF

cat > app/core/__init__.py << 'EOF'
EOF

cat > app/core/security.py << 'EOF'
import bcrypt
import jwt
from datetime import datetime, timedelta
from app.config import settings

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_token(user_id: int, role: str) -> str:
    payload = {"user_id": user_id, "role": role, "exp": datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRE_HOURS)}
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")

def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
EOF

cat > app/core/auth_middleware.py << 'EOF'
from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.security import decode_token

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Неверный или истекший токен")
    return payload

async def get_admin_user(user=Depends(get_current_user)):
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Нет доступа")
    return user
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
            admin = User(full_name="Администратор", login="admin", password_hash=hash_password("admin123"), role="admin")
            session.add(admin)
            await session.commit()
            logger.info("Создан администратор: admin / admin123")
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
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("CRM start")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_admin()
    logger.info("CRM ready")
    yield
    logger.info("CRM stop")

app = FastAPI(title="CRM Yurist", version="3.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(auth_router)
app.include_router(dashboard_router)
app.include_router(clients_router)
app.include_router(cases_router)
app.include_router(stages_router)
app.include_router(documents_router)
app.include_router(users_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/admin")
async def admin_panel():
    return FileResponse("app/static/admin.html")
EOF

echo "Часть 1 готова"
cat > app/models/__init__.py << 'EOF'
from app.models.client import Client
from app.models.case import Case
from app.models.stage import Stage
from app.models.document import Document
from app.models.user import User
from app.models.activity import Activity
EOF

cat > app/models/client.py << 'EOF'
from sqlalchemy import String, Integer, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Client(Base):
    __tablename__ = "clients"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="active")
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    cases = relationship("Case", back_populates="client", cascade="all, delete-orphan")
EOF

cat > app/models/case.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database import Base

class Case(Base):
    __tablename__ = "cases"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True, index=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"), index=True)
    title: Mapped[str] = mapped_column(String(500))
    case_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="new", index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    client = relationship("Client", back_populates="cases")
    stages = relationship("Stage", back_populates="case", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="case", cascade="all, delete-orphan")
    activities = relationship("Activity", back_populates="case", cascade="all, delete-orphan")
EOF

cat > app/models/stage.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database import Base

class Stage(Base):
    __tablename__ = "stages"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    assigned_to: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="pending")
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    case = relationship("Case", back_populates="stages")
    assigned_user = relationship("User", foreign_keys=[assigned_to])
EOF

cat > app/models/document.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database import Base

class Document(Base):
    __tablename__ = "documents"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    name: Mapped[str] = mapped_column(String(500))
    file_path: Mapped[str] = mapped_column(String(1000))
    file_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    uploaded_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    case = relationship("Case", back_populates="documents")
    uploader = relationship("User", foreign_keys=[uploaded_by])
EOF

cat > app/models/user.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.database import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(255))
    login: Mapped[str] = mapped_column(String(100), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(50), default="lawyer")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > app/models/activity.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database import Base

class Activity(Base):
    __tablename__ = "activities"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    action: Mapped[str] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    case = relationship("Case", back_populates="activities")
    user = relationship("User", foreign_keys=[user_id])
EOF

cat > app/api/__init__.py << 'EOF'
EOF

cat > app/api/schemas/__init__.py << 'EOF'
EOF

cat > app/api/schemas/client.py << 'EOF'
from pydantic import BaseModel, Field

class ClientCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    phone: str | None = None
    email: str | None = None
    status: str = "active"

class ClientUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    status: str | None = None
EOF

cat > app/api/schemas/case.py << 'EOF'
from pydantic import BaseModel, Field

class CaseCreate(BaseModel):
    client_id: int
    title: str = Field(min_length=1, max_length=500)
    case_type: str | None = None
    description: str | None = None
    status: str = "new"

class CaseUpdate(BaseModel):
    title: str | None = None
    case_type: str | None = None
    description: str | None = None
    status: str | None = None
EOF

cat > app/api/schemas/stage.py << 'EOF'
from pydantic import BaseModel, Field

class StageCreate(BaseModel):
    case_id: int
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    assigned_to: int | None = None
    order: int = 0

class StageUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    assigned_to: int | None = None
    status: str | None = None
    is_completed: bool | None = None
    order: int | None = None
EOF

cat > app/api/schemas/user.py << 'EOF'
from pydantic import BaseModel, Field

class UserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    login: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1, max_length=255)
    role: str = "lawyer"

class UserLogin(BaseModel):
    login: str
    password: str
EOF

echo "Часть 2 готова"
cat > app/repositories/__init__.py << 'EOF'
EOF

cat > app/repositories/client_repo.py << 'EOF'
from sqlalchemy import select, update, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all(self, status: str | None = None, search: str | None = None, skip: int = 0, limit: int = 50) -> list[Client]:
        query = select(Client)
        if status:
            query = query.where(Client.status == status)
        if search:
            query = query.where(Client.full_name.ilike(f"%{search}%") | Client.phone.ilike(f"%{search}%"))
        result = await self.session.execute(query.order_by(Client.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())

    async def get_by_id(self, client_id: int) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.id == client_id))
        return result.scalar_one_or_none()

    async def create(self, client: Client) -> Client:
        self.session.add(client)
        await self.session.flush()
        return client

    async def update(self, client_id: int, **kwargs) -> Client | None:
        await self.session.execute(update(Client).where(Client.id == client_id).values(**kwargs))
        await self.session.flush()
        return await self.get_by_id(client_id)

    async def delete(self, client_id: int) -> bool:
        client = await self.get_by_id(client_id)
        if client:
            await self.session.execute(delete(Client).where(Client.id == client_id))
            await self.session.flush()
            return True
        return False

    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Client))
        return result.scalar() or 0
EOF

cat > app/repositories/case_repo.py << 'EOF'
from sqlalchemy import select, update, func, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.case import Case
from app.models.activity import Activity

class CaseRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all(self, client_id: int | None = None, status: str | None = None, case_type: str | None = None, skip: int = 0, limit: int = 50) -> list[Case]:
        query = select(Case).options(selectinload(Case.client))
        if client_id:
            query = query.where(Case.client_id == client_id)
        if status:
            query = query.where(Case.status == status)
        if case_type:
            query = query.where(Case.case_type == case_type)
        result = await self.session.execute(query.order_by(Case.updated_at.desc()).offset(skip).limit(limit))
        return list(result.scalars().all())

    async def get_by_id(self, case_id: int) -> Case | None:
        result = await self.session.execute(
            select(Case).options(
                selectinload(Case.client),
                selectinload(Case.stages),
                selectinload(Case.documents),
                selectinload(Case.activities).selectinload(Activity.user)
            ).where(Case.id == case_id)
        )
        return result.scalar_one_or_none()

    async def create(self, case: Case) -> Case:
        self.session.add(case)
        await self.session.flush()
        return case

    async def update(self, case_id: int, **kwargs) -> Case | None:
        await self.session.execute(update(Case).where(Case.id == case_id).values(**kwargs))
        await self.session.flush()
        return await self.get_by_id(case_id)

    async def delete(self, case_id: int) -> bool:
        case = await self.get_by_id(case_id)
        if case:
            await self.session.execute(delete(Case).where(Case.id == case_id))
            await self.session.flush()
            return True
        return False

    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Case))
        return result.scalar() or 0

    async def get_status_counts(self) -> dict:
        result = await self.session.execute(select(Case.status, func.count(Case.id)).group_by(Case.status))
        return {row[0]: row[1] for row in result.all()}
EOF

cat > app/repositories/stage_repo.py << 'EOF'
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.stage import Stage

class StageRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_case(self, case_id: int) -> list[Stage]:
        result = await self.session.execute(select(Stage).where(Stage.case_id == case_id).order_by(Stage.order))
        return list(result.scalars().all())

    async def create(self, stage: Stage) -> Stage:
        self.session.add(stage)
        await self.session.flush()
        return stage

    async def update(self, stage_id: int, **kwargs) -> Stage | None:
        await self.session.execute(update(Stage).where(Stage.id == stage_id).values(**kwargs))
        await self.session.flush()
        result = await self.session.execute(select(Stage).where(Stage.id == stage_id))
        return result.scalar_one_or_none()

    async def delete(self, stage_id: int) -> bool:
        stage = await self.session.execute(select(Stage).where(Stage.id == stage_id))
        s = stage.scalar_one_or_none()
        if s:
            await self.session.execute(delete(Stage).where(Stage.id == stage_id))
            await self.session.flush()
            return True
        return False
EOF

cat > app/repositories/document_repo.py << 'EOF'
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.document import Document

class DocumentRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_case(self, case_id: int) -> list[Document]:
        result = await self.session.execute(select(Document).where(Document.case_id == case_id).order_by(Document.created_at.desc()))
        return list(result.scalars().all())

    async def create(self, doc: Document) -> Document:
        self.session.add(doc)
        await self.session.flush()
        return doc

    async def delete(self, doc_id: int) -> bool:
        doc = await self.session.execute(select(Document).where(Document.id == doc_id))
        d = doc.scalar_one_or_none()
        if d:
            await self.session.execute(delete(Document).where(Document.id == doc_id))
            await self.session.flush()
            return True
        return False
EOF

cat > app/repositories/user_repo.py << 'EOF'
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User

class UserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_all(self) -> list[User]:
        result = await self.session.execute(select(User).where(User.is_active == True))
        return list(result.scalars().all())

    async def get_by_id(self, user_id: int) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_login(self, login: str) -> User | None:
        result = await self.session.execute(select(User).where(User.login == login))
        return result.scalar_one_or_none()

    async def create(self, user: User) -> User:
        self.session.add(user)
        await self.session.flush()
        return user

    async def update(self, user_id: int, **kwargs) -> User | None:
        await self.session.execute(update(User).where(User.id == user_id).values(**kwargs))
        await self.session.flush()
        return await self.get_by_id(user_id)
EOF

cat > app/repositories/activity_repo.py << 'EOF'
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.activity import Activity

class ActivityRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_case(self, case_id: int) -> list[Activity]:
        result = await self.session.execute(select(Activity).where(Activity.case_id == case_id).order_by(Activity.created_at.desc()))
        return list(result.scalars().all())

    async def create(self, activity: Activity) -> Activity:
        self.session.add(activity)
        await self.session.flush()
        return activity
EOF

echo "Часть 3 готова"
cat > app/api/routes/__init__.py << 'EOF'
EOF

cat > app/api/routes/auth.py << 'EOF'
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
EOF

cat > app/api/routes/clients.py << 'EOF'
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
EOF

cat > app/api/routes/cases.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.case_repo import CaseRepository
from app.repositories.activity_repo import ActivityRepository
from app.api.schemas.case import CaseCreate, CaseUpdate
from app.models.case import Case
from app.models.activity import Activity
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["cases"])

@router.get("/cases")
async def get_cases(client_id: int | None = Query(default=None), status: str | None = Query(default=None), case_type: str | None = Query(default=None), skip: int = 0, limit: int = 50, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    cases = await repo.get_all(client_id=client_id, status=status, case_type=case_type, skip=skip, limit=limit)
    return [{"id": c.id, "title": c.title, "case_type": c.case_type, "status": c.status, "client_name": c.client.full_name if c.client else "—"} for c in cases]

@router.get("/cases/{case_id}")
async def get_case(case_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    case = await repo.get_by_id(case_id)
    if not case:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    return {
        "id": case.id, "title": case.title, "case_type": case.case_type, "status": case.status, "description": case.description,
        "client": {"id": case.client.id, "full_name": case.client.full_name, "phone": case.client.phone} if case.client else None,
        "stages": [{"id": s.id, "name": s.name, "status": s.status, "is_completed": s.is_completed, "assigned_to": s.assigned_to} for s in case.stages],
        "documents": [{"id": d.id, "name": d.name, "file_path": d.file_path} for d in case.documents],
        "activities": [{"id": a.id, "action": a.action, "description": a.description, "user_name": a.user.full_name if a.user else "—"} for a in case.activities]
    }

@router.post("/cases")
async def create_case(data: CaseCreate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    case = Case(client_id=data.client_id, title=data.title, case_type=data.case_type, description=data.description, status=data.status)
    result = await repo.create(case)
    await ActivityRepository(session).create(Activity(case_id=result.id, user_id=user["user_id"], action="create", description="Дело создано"))
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/cases/{case_id}")
async def update_case(case_id: int, data: CaseUpdate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    case = await repo.update(case_id, **updates)
    if not case:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    await ActivityRepository(session).create(Activity(case_id=case_id, user_id=user["user_id"], action="update", description=str(updates)))
    await session.commit()
    return {"ok": True}

@router.delete("/cases/{case_id}")
async def delete_case(case_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = CaseRepository(session)
    ok = await repo.delete(case_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Дело не найдено")
    await session.commit()
    return {"ok": True}
EOF

cat > app/api/routes/stages.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.stage_repo import StageRepository
from app.api.schemas.stage import StageCreate, StageUpdate
from app.models.stage import Stage
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["stages"])

@router.post("/stages")
async def create_stage(data: StageCreate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    stage = Stage(case_id=data.case_id, name=data.name, description=data.description, assigned_to=data.assigned_to, order=data.order)
    result = await repo.create(stage)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/stages/{stage_id}")
async def update_stage(stage_id: int, data: StageUpdate, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    stage = await repo.update(stage_id, **updates)
    if not stage:
        raise HTTPException(status_code=404, detail="Этап не найден")
    await session.commit()
    return {"ok": True}

@router.delete("/stages/{stage_id}")
async def delete_stage(stage_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = StageRepository(session)
    ok = await repo.delete(stage_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Этап не найден")
    await session.commit()
    return {"ok": True}
EOF

cat > app/api/routes/documents.py << 'EOF'
import uuid, os, aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.document_repo import DocumentRepository
from app.models.document import Document
from app.config import settings
from app.core.auth_middleware import get_current_user

router = APIRouter(prefix="/api", tags=["documents"])

ALLOWED_TYPES = {"application/pdf", "image/jpeg", "image/png", "image/jpg", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}

@router.post("/documents/upload")
async def upload_document(case_id: int = Form(...), file: UploadFile = File(...), session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    if file.content_type and file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail=f"Недопустимый тип файла: {file.content_type}")
    ext = os.path.splitext(file.filename or "file")[1]
    filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    total_size = 0
    max_size = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    async with aiofiles.open(filepath, "wb") as f:
        while chunk := await file.read(1024 * 1024):
            total_size += len(chunk)
            if total_size > max_size:
                await f.close()
                os.remove(filepath)
                raise HTTPException(status_code=400, detail=f"Файл больше {settings.MAX_FILE_SIZE_MB} МБ")
            await f.write(chunk)
    repo = DocumentRepository(session)
    doc = Document(case_id=case_id, name=file.filename or "file", file_path=f"/static/uploads/{filename}", file_type=file.content_type, uploaded_by=user["user_id"])
    result = await repo.create(doc)
    await session.commit()
    return {"ok": True, "id": result.id, "path": f"/static/uploads/{filename}"}

@router.delete("/documents/{doc_id}")
async def delete_document(doc_id: int, session: AsyncSession = Depends(get_session), user=Depends(get_current_user)):
    repo = DocumentRepository(session)
    ok = await repo.delete(doc_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Документ не найден")
    await session.commit()
    return {"ok": True}
EOF

cat > app/api/routes/users.py << 'EOF'
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
EOF

echo "Часть 4 готова"
cat > app/static/admin.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRM Юрист</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:'Segoe UI',sans-serif;background:#f0f2f5;color:#1a1a2e}
        .login-overlay{display:flex;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.6);justify-content:center;align-items:center;z-index:9999}
        .login-box{background:white;padding:40px;border-radius:16px;width:90%;max-width:400px;text-align:center}
        .login-box h2{margin-bottom:24px;color:#1a1a2e}
        .login-box input{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:8px;font-size:16px}
        .login-box button{width:100%;padding:14px;background:#1a1a2e;color:white;border:none;border-radius:8px;font-size:16px;font-weight:600;cursor:pointer;margin-top:8px}
        .login-error{color:#c0392b;font-size:14px;margin-top:8px;min-height:20px}
        .app-layout{display:flex;min-height:100vh}
        .sidebar{width:240px;background:#1a1a2e;color:white;padding:20px;display:flex;flex-direction:column;gap:10px}
        .sidebar h2{color:#c9a96e;margin-bottom:20px;font-size:20px}
        .sidebar a{color:white;text-decoration:none;padding:12px 16px;border-radius:8px;display:block;font-size:15px;transition:all 0.2s;cursor:pointer}
        .sidebar a:hover{background:#2a2a4e}
        .sidebar a.active{background:#c9a96e;color:#1a1a2e;font-weight:600}
        .main{flex:1;padding:30px}
        .header{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}
        .header h1{font-size:24px}
        .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}
        .stat-card{background:white;padding:20px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        .stat-card .value{font-size:32px;font-weight:700;color:#c9a96e}
        .stat-card .label{color:#888;font-size:14px;margin-top:4px}
        table{width:100%;border-collapse:collapse;background:white;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08)}
        th{background:#1a1a2e;color:white;padding:12px 16px;text-align:left;font-weight:600}
        td{padding:12px 16px;border-bottom:1px solid #eee}
        tr:hover{background:#f8f9fa}
        .btn{padding:8px 16px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:600;margin:2px}
        .btn-primary{background:#1a1a2e;color:white}
        .btn-success{background:#27ae60;color:white}
        .btn-danger{background:#c0392b;color:white}
        .badge{padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
        .badge-active{background:#27ae60;color:white}
        .badge-new{background:#3498db;color:white}
        .badge-closed{background:#888;color:white}
        .modal{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);justify-content:center;align-items:center;z-index:1000}
        .modal.active{display:flex}
        .modal-content{background:white;padding:30px;border-radius:12px;width:90%;max-width:500px;max-height:80vh;overflow-y:auto}
        .form-group{margin-bottom:16px}
        .form-group label{display:block;font-weight:600;margin-bottom:4px;font-size:14px}
        .form-group input,.form-group select,.form-group textarea{width:100%;padding:10px;border:1px solid #ddd;border-radius:8px;font-size:15px}
        .form-group textarea{min-height:80px;resize:vertical}
        .form-actions{display:flex;gap:10px;justify-content:flex-end;margin-top:20px}
        .logout-btn{background:#c0392b;color:white;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;font-weight:600}
        .upload-zone{border:2px dashed #ddd;border-radius:12px;padding:40px;text-align:center;cursor:pointer;transition:all 0.2s;margin:16px 0}
        .upload-zone:hover{border-color:#c9a96e;background:#fafafa}
        @media(max-width:768px){.sidebar{display:none}.stats{grid-template-columns:repeat(2,1fr)}}
    </style>
</head>
<body>
    <div class="login-overlay" id="loginOverlay">
        <div class="login-box">
            <h2>⚖️ CRM Юрист</h2>
            <input type="text" id="loginInput" placeholder="Логин" value="admin">
            <input type="password" id="passInput" placeholder="Пароль" value="admin123">
            <button onclick="doLogin()">Войти</button>
            <div class="login-error" id="loginError"></div>
        </div>
    </div>

    <div class="app-layout" id="appLayout" style="display:none">
        <div class="sidebar">
            <h2>⚖️ CRM Юрист</h2>
            <a class="active" onclick="showTab('dashboard')">📊 Дашборд</a>
            <a onclick="showTab('clients')">👥 Клиенты</a>
            <a onclick="showTab('cases')">📁 Дела</a>
            <a onclick="showTab('users')">👨‍💼 Сотрудники</a>
            <button class="logout-btn" onclick="doLogout()" style="margin-top:auto">🚪 Выйти</button>
        </div>
        <div class="main" id="content">
            <div class="header"><h1>📊 Дашборд</h1></div>
            <div class="stats" id="stats"></div>
            <div id="table-container"></div>
        </div>
    </div>

    <div class="modal" id="modal"><div class="modal-content" id="modal-content"></div></div>

    <script>
        let TOKEN = localStorage.getItem('crm_token') || '';
        let currentTab = 'dashboard';

        async function api(url, options = {}) {
            const headers = { ...options.headers };
            if (TOKEN) headers['Authorization'] = 'Bearer ' + TOKEN;
            const res = await fetch(url, { ...options, headers });
            if (res.status === 401) { doLogout(); throw new Error('Unauthorized'); }
            return res.json();
        }

        async function doLogin() {
            const login = document.getElementById('loginInput').value;
            const password = document.getElementById('passInput').value;
            document.getElementById('loginError').textContent = '';
            try {
                const res = await fetch('/api/auth/login', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({login, password})
                });
                const data = await res.json();
                if (data.ok) {
                    TOKEN = data.token;
                    localStorage.setItem('crm_token', TOKEN);
                    document.getElementById('loginOverlay').style.display = 'none';
                    document.getElementById('appLayout').style.display = 'flex';
                    showTab('dashboard');
                } else {
                    document.getElementById('loginError').textContent = data.detail || 'Ошибка входа';
                }
            } catch (e) {
                document.getElementById('loginError').textContent = 'Ошибка соединения';
            }
        }

        function doLogout() {
            TOKEN = '';
            localStorage.removeItem('crm_token');
            document.getElementById('loginOverlay').style.display = 'flex';
            document.getElementById('appLayout').style.display = 'none';
        }

        async function showTab(tab) {
            currentTab = tab;
            document.querySelectorAll('.sidebar a').forEach(a => a.classList.remove('active'));
            event?.target?.classList?.add('active');
            document.getElementById('table-container').innerHTML = '';
            if (tab === 'dashboard') await loadDashboard();
            else if (tab === 'clients') await loadClients();
            else if (tab === 'cases') await loadCases();
            else if (tab === 'users') await loadUsers();
        }

        async function loadDashboard() {
            document.querySelector('.header h1').textContent = '📊 Дашборд';
            const stats = await api('/api/dashboard/stats');
            document.getElementById('stats').innerHTML = `
                <div class="stat-card"><div class="value">${stats.total_clients||0}</div><div class="label">Всего клиентов</div></div>
                <div class="stat-card"><div class="value">${stats.total_cases||0}</div><div class="label">Всего дел</div></div>
                <div class="stat-card"><div class="value">${stats.active_cases||0}</div><div class="label">Активных дел</div></div>
                <div class="stat-card"><div class="value">${stats.closed_cases||0}</div><div class="label">Закрытых дел</div></div>
            `;
        }

        async function loadClients() {
            document.querySelector('.header h1').textContent = '👥 Клиенты';
            document.getElementById('stats').innerHTML = '';
            const clients = await api('/api/clients');
            let html = '<button class="btn btn-success" onclick="showClientForm()" style="margin-bottom:16px">➕ Добавить клиента</button><table><tr><th>ID</th><th>ФИО</th><th>Телефон</th><th>Email</th><th>Статус</th><th></th></tr>';
            clients.forEach(c => {
                html += `<tr><td>${c.id}</td><td>${c.full_name||''}</td><td>${c.phone||'—'}</td><td>${c.email||'—'}</td><td><span class="badge badge-${c.status==='active'?'active':'closed'}">${c.status||'—'}</span></td><td><button class="btn btn-primary" onclick="editClient(${c.id})">✏️</button> <button class="btn btn-danger" onclick="deleteClient(${c.id})">🗑️</button></td></tr>`;
            });
            html += '</table>';
            document.getElementById('table-container').innerHTML = html;
        }

        async function loadCases() {
            document.querySelector('.header h1').textContent = '📁 Дела';
            document.getElementById('stats').innerHTML = '';
            const cases = await api('/api/cases');
            let html = '<button class="btn btn-success" onclick="showCaseForm()" style="margin-bottom:16px">➕ Добавить дело</button><table><tr><th>ID</th><th>Название</th><th>Тип</th><th>Клиент</th><th>Статус</th><th></th></tr>';
            cases.forEach(c => {
                html += `<tr><td>${c.id}</td><td><a href="#" onclick="viewCase(${c.id})" style="color:#3498db;text-decoration:none">${c.title||''}</a></td><td>${c.case_type||'—'}</td><td>${c.client_name||'—'}</td><td><span class="badge badge-${c.status==='new'?'new':c.status==='active'?'active':'closed'}">${c.status||'—'}</span></td><td><button class="btn btn-primary" onclick="editCase(${c.id})">✏️</button> <button class="btn btn-danger" onclick="deleteCase(${c.id})">🗑️</button></td></tr>`;
            });
            html += '</table>';
            document.getElementById('table-container').innerHTML = html;
        }

        async function loadUsers() {
            document.querySelector('.header h1').textContent = '👨‍💼 Сотрудники';
            document.getElementById('stats').innerHTML = '';
            const users = await api('/api/users');
            let html = '<button class="btn btn-success" onclick="showUserForm()" style="margin-bottom:16px">➕ Добавить сотрудника</button><table><tr><th>ID</th><th>ФИО</th><th>Логин</th><th>Роль</th></tr>';
            users.forEach(u => {
                html += `<tr><td>${u.id}</td><td>${u.full_name||''}</td><td>${u.login||''}</td><td>${u.role||'—'}</td></tr>`;
            });
            html += '</table>';
            document.getElementById('table-container').innerHTML = html;
        }

        function showClientForm() {
            document.getElementById('modal').classList.add('active');
            document.getElementById('modal-content').innerHTML = `
                <h2>Добавить клиента</h2>
                <div class="form-group"><label>ФИО</label><input id="cfname"></div>
                <div class="form-group"><label>Телефон</label><input id="cphone"></div>
                <div class="form-group"><label>Email</label><input id="cemail"></div>
                <div class="form-actions"><button class="btn btn-primary" onclick="saveClient()">Сохранить</button><button class="btn btn-danger" onclick="closeModal()">Отмена</button></div>
            `;
        }

        async function saveClient() {
            const data = {full_name:document.getElementById('cfname').value, phone:document.getElementById('cphone').value, email:document.getElementById('cemail').value};
            await api('/api/clients', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)});
            closeModal(); loadClients();
        }

        function showCaseForm() {
            document.getElementById('modal').classList.add('active');
            document.getElementById('modal-content').innerHTML = `
                <h2>Добавить дело</h2>
                <div class="form-group"><label>Клиент ID</label><input id="cclient" type="number"></div>
                <div class="form-group"><label>Название</label><input id="ctitle"></div>
                <div class="form-group"><label>Тип</label><input id="ctype"></div>
                <div class="form-group"><label>Описание</label><textarea id="cdesc"></textarea></div>
                <div class="form-actions"><button class="btn btn-primary" onclick="saveCase()">Сохранить</button><button class="btn btn-danger" onclick="closeModal()">Отмена</button></div>
            `;
        }

        async function saveCase() {
            const data = {client_id:parseInt(document.getElementById('cclient').value), title:document.getElementById('ctitle').value, case_type:document.getElementById('ctype').value, description:document.getElementById('cdesc').value};
            await api('/api/cases', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)});
            closeModal(); loadCases();
        }

        function showUserForm() {
            document.getElementById('modal').classList.add('active');
            document.getElementById('modal-content').innerHTML = `
                <h2>Добавить сотрудника</h2>
                <div class="form-group"><label>ФИО</label><input id="ufname"></div>
                <div class="form-group"><label>Логин</label><input id="ulogin"></div>
                <div class="form-group"><label>Пароль</label><input id="upass" type="password"></div>
                <div class="form-group"><label>Роль</label><select id="urole"><option value="lawyer">Юрист</option><option value="admin">Админ</option><option value="secretary">Секретарь</option></select></div>
                <div class="form-actions"><button class="btn btn-primary" onclick="saveUser()">Сохранить</button><button class="btn btn-danger" onclick="closeModal()">Отмена</button></div>
            `;
        }

        async function saveUser() {
            const data = {full_name:document.getElementById('ufname').value, login:document.getElementById('ulogin').value, password:document.getElementById('upass').value, role:document.getElementById('urole').value};
            await api('/api/users', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)});
            closeModal(); loadUsers();
        }

        async function deleteClient(id) { if (confirm('Удалить клиента?')) { await api('/api/clients/'+id, {method:'DELETE'}); loadClients(); } }
        async function deleteCase(id) { if (confirm('Удалить дело?')) { await api('/api/cases/'+id, {method:'DELETE'}); loadCases(); } }

        async function viewCase(id) {
            const c = await api('/api/cases/'+id);
            document.getElementById('modal').classList.add('active');
            let docsHtml = c.documents?.map(d => `<p><a href="${d.file_path}" target="_blank">📄 ${d.name}</a></p>`).join('') || '<p>Нет документов</p>';
            document.getElementById('modal-content').innerHTML = `
                <h2>${c.title}</h2>
                <p><b>Клиент:</b> ${c.client?.full_name||'—'} | <b>Тип:</b> ${c.case_type||'—'} | <b>Статус:</b> ${c.status}</p>
                <h3 style="margin-top:16px">Документы</h3>${docsHtml}
                <div class="upload-zone" onclick="document.getElementById('fileInput').click()">📎 Нажмите для загрузки документа</div>
                <input type="file" id="fileInput" style="display:none" onchange="uploadDoc(${id})">
                <div class="form-actions"><button class="btn btn-danger" onclick="closeModal()">Закрыть</button></div>
            `;
        }

        async function uploadDoc(caseId) {
            const file = document.getElementById('fileInput').files[0];
            if (!file) return;
            const fd = new FormData();
            fd.append('file', file);
            fd.append('case_id', caseId);
            const res = await fetch('/api/documents/upload', {method:'POST', headers:{'Authorization':'Bearer '+TOKEN}, body:fd});
            const data = await res.json();
            if (data.ok) { alert('Документ загружен!'); viewCase(caseId); }
            else { alert(data.detail || 'Ошибка загрузки'); }
        }

        function closeModal() { document.getElementById('modal').classList.remove('active'); }

        if (TOKEN) {
            document.getElementById('loginOverlay').style.display = 'none';
            document.getElementById('appLayout').style.display = 'flex';
            showTab('dashboard');
        }
    </script>
</body>
</html>
EOF

echo ""
echo "=============================================="
echo "  CRM ДЛЯ ЮРИСТА v3.0 — ФИНАЛ"
echo "  - JWT + bcrypt"
echo "  - Seed admin: admin / admin123"
echo "  - Потоковая загрузка файлов"
echo "  - Полный CRUD + Дашборд"
echo "  Запусти: bash setup.sh"
echo "=============================================="