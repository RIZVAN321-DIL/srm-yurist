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
