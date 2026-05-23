from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.notifications.repository import NotificationRepository
from app.domain.notifications.schema import (
    NotificationListResponse,
    NotificationDetailResponse,
    NotificationReadResponse,
    CommonResponse,
)


class NotificationService:
    def __init__(self, db: AsyncSession):
        self.repository = NotificationRepository(db)

    async def get_notifications(self, patient_id: int, page: int, size: int) -> NotificationListResponse:
        items, total = await self.repository.get_page(patient_id, page, size)
        return NotificationListResponse(
            items=items,
            page=page,
            size=size,
            total=total,
        )

    async def get_notification(self, notification_id: int) -> NotificationDetailResponse:
        notification = await self.repository.get_by_id(notification_id)
        if not notification:
            raise ValueError("알림을 찾을 수 없습니다")
        return NotificationDetailResponse.from_orm(notification)

    async def read_notification(self, notification_id: int) -> NotificationReadResponse:
        notification = await self.repository.mark_as_read(notification_id)
        if not notification:
            raise ValueError("알림을 찾을 수 없습니다")
        return NotificationReadResponse.from_orm(notification)

    async def read_all_notifications(self, patient_id: int) -> CommonResponse:
        await self.repository.mark_all_as_read(patient_id)
        return CommonResponse(success=True, message="모든 알림을 읽음 상태로 변경했습니다")
