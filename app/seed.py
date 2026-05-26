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
