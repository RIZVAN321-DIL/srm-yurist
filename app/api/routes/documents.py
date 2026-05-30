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
