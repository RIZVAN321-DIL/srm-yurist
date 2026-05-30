from sqlalchemy import select, func
from app.database import async_session
from app.models.user import User
from app.models.case_template import CaseTemplate
from app.core.security import hash_password
from app.logger import logger
import json

TEMPLATES = [
    {
        "name": "Ипотека (покупка)",
        "case_type": "ipoteka_purchase",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Сбор документов клиента", "days": 5},
            {"name": "Сбор документов на объект", "days": 5},
            {"name": "Подача заявки в банк", "days": 1},
            {"name": "Ожидание решения банка", "days": 7},
            {"name": "Оценка недвижимости", "days": 3},
            {"name": "Подготовка договора купли-продажи", "days": 2},
            {"name": "Подготовка ипотечного договора", "days": 2},
            {"name": "Сделка (подписание)", "days": 1},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 9},
            {"name": "Получение выписки ЕГРН", "days": 1},
        ]
    },
    {
        "name": "Маткапитал (строительство)",
        "case_type": "matkap_build",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Проверка остатка сертификата", "days": 1},
            {"name": "Сбор документов", "days": 5},
            {"name": "Уведомление о строительстве", "days": 1},
            {"name": "Ожидание ответа администрации", "days": 14},
            {"name": "Подача в СФР", "days": 1},
            {"name": "Ожидание решения СФР", "days": 14},
            {"name": "Получение 1-й половины (50%)", "days": 5},
            {"name": "Контрольное фото стройки (через 6 мес.)", "days": 180},
            {"name": "Подача подтверждения в СФР", "days": 1},
            {"name": "Получение 2-й половины (50%)", "days": 5},
            {"name": "Технический план", "days": 7},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 12},
            {"name": "Выделение долей (нотариус)", "days": 14},
        ]
    },
    {
        "name": "Маткапитал (покупка)",
        "case_type": "matkap_purchase",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Проверка остатка сертификата", "days": 1},
            {"name": "Сбор документов", "days": 5},
            {"name": "Проверка юридической чистоты объекта", "days": 3},
            {"name": "Подготовка ДКП", "days": 2},
            {"name": "Подача в СФР", "days": 1},
            {"name": "Ожидание решения СФР", "days": 14},
            {"name": "Сделка (подписание)", "days": 1},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 9},
            {"name": "Выделение долей (нотариус)", "days": 14},
        ]
    },
    {
        "name": "Маткапитал (компенсация)",
        "case_type": "matkap_compensation",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Проверка остатка сертификата", "days": 1},
            {"name": "Сбор документов", "days": 5},
            {"name": "Акт осмотра/заключение", "days": 3},
            {"name": "Подача в СФР", "days": 1},
            {"name": "Ожидание решения СФР", "days": 14},
            {"name": "Получение компенсации", "days": 5},
        ]
    },
    {
        "name": "Соцконтракт (ИП/самозанятость)",
        "case_type": "sockontrakt_business",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Проверка доходов", "days": 1},
            {"name": "Сбор документов", "days": 5},
            {"name": "Составление бизнес-плана", "days": 3},
            {"name": "Подача в соцзащиту", "days": 1},
            {"name": "Ожидание комиссии", "days": 14},
            {"name": "Защита бизнес-плана", "days": 1},
            {"name": "Подписание контракта", "days": 1},
            {"name": "Получение выплаты", "days": 5},
            {"name": "Отчётность (через 1 мес.)", "days": 30},
            {"name": "Отчётность (через 6 мес.)", "days": 180},
            {"name": "Итоговая отчётность (через 12 мес.)", "days": 365},
        ]
    },
    {
        "name": "Соцконтракт (ЛПХ)",
        "case_type": "sockontrakt_farm",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Проверка доходов", "days": 1},
            {"name": "Сбор документов", "days": 5},
            {"name": "Составление бизнес-плана", "days": 3},
            {"name": "Подача в соцзащиту", "days": 1},
            {"name": "Ожидание комиссии", "days": 14},
            {"name": "Подписание контракта", "days": 1},
            {"name": "Получение выплаты", "days": 5},
            {"name": "Закупка (скот/техника/семена)", "days": 14},
            {"name": "Отчётность (через 3 мес.)", "days": 90},
            {"name": "Итоговая отчётность (через 12 мес.)", "days": 365},
        ]
    },
    {
        "name": "Оформление дома",
        "case_type": "house_registration",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Выезд на объект (замеры)", "days": 3},
            {"name": "Подготовка технического плана", "days": 7},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 12},
            {"name": "Получение выписки ЕГРН", "days": 1},
        ]
    },
    {
        "name": "Оформление участка (межевание)",
        "case_type": "land_survey",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Выезд геодезиста", "days": 3},
            {"name": "Подготовка межевого плана", "days": 7},
            {"name": "Согласование границ с соседями", "days": 14},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация", "days": 12},
            {"name": "Получение выписки ЕГРН", "days": 1},
        ]
    },
    {
        "name": "Дачная амнистия",
        "case_type": "dacha_amnesty",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Сбор документов на участок", "days": 5},
            {"name": "Заполнение декларации", "days": 1},
            {"name": "Технический план (если нужно)", "days": 7},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 12},
            {"name": "Получение выписки ЕГРН", "days": 1},
        ]
    },
    {
        "name": "Реконструкция / достройка",
        "case_type": "reconstruction",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Выезд на объект", "days": 3},
            {"name": "Технический план (до изменений)", "days": 7},
            {"name": "Уведомление о реконструкции", "days": 1},
            {"name": "Ожидание ответа администрации", "days": 14},
            {"name": "Технический план (после изменений)", "days": 7},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация изменений", "days": 12},
            {"name": "Получение выписки ЕГРН", "days": 1},
        ]
    },
    {
        "name": "Комплексное сопровождение",
        "case_type": "full_support",
        "stages": [
            {"name": "Консультация", "days": 1},
            {"name": "Анализ объекта (юр. чистоты)", "days": 3},
            {"name": "Сбор документов клиента", "days": 5},
            {"name": "Сбор документов на объект", "days": 7},
            {"name": "Подача в банк (ипотека)", "days": 1},
            {"name": "Ожидание решения банка", "days": 7},
            {"name": "Подача в СФР (маткапитал)", "days": 1},
            {"name": "Ожидание решения СФР", "days": 14},
            {"name": "Оценка недвижимости", "days": 3},
            {"name": "Подготовка договоров", "days": 3},
            {"name": "Сделка (подписание)", "days": 1},
            {"name": "Подача в Росреестр", "days": 1},
            {"name": "Регистрация права", "days": 12},
            {"name": "Выделение долей", "days": 14},
        ]
    },
]

async def seed_admin():
    async with async_session() as session:
        count = await session.scalar(select(func.count()).select_from(User))
        if count == 0:
            admin = User(
                full_name="Администратор",
                login="admin",
                password_hash=hash_password("admin123"),
                role="admin",
                force_password_change=True
            )
            session.add(admin)
            await session.commit()
            logger.info("Создан администратор: admin / admin123")

        tcount = await session.scalar(select(func.count()).select_from(CaseTemplate))
        if tcount == 0:
            for t in TEMPLATES:
                template = CaseTemplate(
                    name=t["name"],
                    case_type=t["case_type"],
                    stages_json=json.dumps(t["stages"], ensure_ascii=False)
                )
                session.add(template)
            await session.commit()
            logger.info(f"Создано {len(TEMPLATES)} шаблонов дел")
