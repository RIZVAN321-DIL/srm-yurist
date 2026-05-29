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

app = FastAPI(title="CRM Yurist", version="6.3.0", lifespan=lifespan)
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
