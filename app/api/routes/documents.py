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
