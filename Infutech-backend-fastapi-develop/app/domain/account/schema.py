from pydantic import BaseModel
from datetime import date


class WithdrawalCheckResponse(BaseModel):
    has_connected_devices: bool
    has_guardian: bool
    unread_notification_count: int


class AccountDeleteRequest(BaseModel):
    birth_date: date


class CommonResponse(BaseModel):
    success: bool
    message: str
