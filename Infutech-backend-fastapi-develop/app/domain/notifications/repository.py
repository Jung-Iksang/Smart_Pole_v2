from __future__ import annotations

from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.notifications.model import Notification


class NotificationRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, notification_id: int) -> Notification | None:
        result = await self.db.execute(
            select(Notification).where(Notification.notification_id == notification_id)
        )
        return result.scalars().first()

    async def get_page(self, patient_id: int, page: int, size: int) -> tuple[list[Notification], int]:
        count_query = select(func.count()).select_from(Notification).where(
            Notification.patient_id == patient_id
        )
        total_result = await self.db.execute(count_query)
        total = total_result.scalar() or 0

        result = await self.db.execute(
            select(Notification)
            .where(Notification.patient_id == patient_id)
            .order_by(Notification.created_at.desc())
            .offset((page - 1) * size)
            .limit(size)
        )
        items = list(result.scalars().all())
        return items, total

    async def mark_as_read(self, notification_id: int) -> Notification | None:
        notification = await self.get_by_id(notification_id)
        if notification:
            notification.is_read = True
            await self.db.commit()
            await self.db.refresh(notification)
        return notification

    async def mark_all_as_read(self, patient_id: int) -> int:
        result = await self.db.execute(
            update(Notification)
            .where(Notification.patient_id == patient_id, Notification.is_read == False)
            .values(is_read=True)
        )
        await self.db.commit()
        return result.rowcount

    async def get_unread_count(self, patient_id: int) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Notification).where(
                Notification.patient_id == patient_id,
                Notification.is_read == False,
            )
        )
        return result.scalar() or 0
