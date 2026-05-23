from typing import Optional
from pydantic import BaseModel


class DashboardPatient(BaseModel):
    name: str


class DashboardDeviceItem(BaseModel):
    device_id: int
    device_name: str
    connection_status: str
    remaining_ml: float
    drop_rate: float
    infusion_status: str
    total_ml: Optional[float] = None
    fluid_name: Optional[str] = None
    battery_level: Optional[int] = None

    class Config:
        from_attributes = True


class DashboardResponse(BaseModel):
    patient: DashboardPatient
    devices: list[DashboardDeviceItem]
    unread_notification_count: int
