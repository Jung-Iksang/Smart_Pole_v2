from datetime import datetime
from pydantic import BaseModel


class NotificationItem(BaseModel):
    notification_id: int
    type: str
    title: str
    message: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationListResponse(BaseModel):
    items: list[NotificationItem]
    page: int
    size: int
    total: int


class NotificationDetailResponse(NotificationItem):
    pass


class NotificationReadResponse(BaseModel):
    notification_id: int
    is_read: bool

    class Config:
        from_attributes = True


class CommonResponse(BaseModel):
    success: bool
    message: str
