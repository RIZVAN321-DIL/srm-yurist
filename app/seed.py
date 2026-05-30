from sqlalchemy import delete
from app.database import async_session
from app.models.user import User
from app.core.security import hash_password
from app.logger import logger

async def seed_admin():
    async with async_session() as session:
        await session.execute(delete(User).where(User.login == "admin"))
        await session.commit()
        admin = User(
            full_name="Администратор",
            login="admin",
            password_hash=hash_password("admin123"),
            role="admin",
            force_password_change=True
        )
        session.add(admin)
        await session.commit()
        logger.info("Администратор сброшен: admin / admin123")
