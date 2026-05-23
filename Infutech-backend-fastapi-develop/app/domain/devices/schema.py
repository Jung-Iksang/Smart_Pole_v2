from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel


class DeviceItem(BaseModel):
    device_id: int
    device_name: str
    device_uid: str
    connection_status: str
    battery_level: int | None
    last_seen_at: datetime | None

    class Config:
        from_attributes = True


class RegisterDeviceRequest(BaseModel):
    qr_code_value: str


class RegisterDeviceResponse(BaseModel):
    device_id: int
    device_name: str
    connection_status: str

    class Config:
        from_attributes = True


class WifiConfigRequest(BaseModel):
    ssid: str
    password: str


class WifiConfigResponse(BaseModel):
    device_id: int
    connection_status: str

    class Config:
        from_attributes = True


class ConnectionStatusResponse(BaseModel):
    device_id: int
    connection_status: str
    last_seen_at: datetime | None

    class Config:
        from_attributes = True


class DeviceDetailResponse(BaseModel):
    device_id: int
    device_name: str
    device_uid: str
    battery_level: int | None
    network_status: str
    last_seen_at: datetime | None

    class Config:
        from_attributes = True


class CommonResponse(BaseModel):
    success: bool
    message: str
