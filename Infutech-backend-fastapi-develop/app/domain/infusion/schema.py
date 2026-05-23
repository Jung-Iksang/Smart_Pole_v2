from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class CurrentInfusionResponse(BaseModel):
    device_id: int
    session_id: int
    remaining_ml: float
    drop_rate: float
    infusion_status: str
    measured_at: datetime

    class Config:
        from_attributes = True


class InfusionHistoryItem(BaseModel):
    measured_at: datetime
    remaining_ml: float
    drop_rate: float
    infusion_status: str

    class Config:
        from_attributes = True


class InfusionHistoryResponse(BaseModel):
    items: list[InfusionHistoryItem]
    page: int
    size: int
    total: int


class InfusionSummaryResponse(BaseModel):
    avg_drop_rate: float
    min_remaining_ml: float
    alert_count: int


class InfusionSetupRequest(BaseModel):
    total_ml: float
    fluid_name: Optional[str] = None


class InfusionSetupResponse(BaseModel):
    session_id: int
    device_id: int
    total_ml: float
    fluid_name: Optional[str] = None
    status: str

    class Config:
        from_attributes = True
