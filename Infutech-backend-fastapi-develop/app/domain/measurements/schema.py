from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel


class MeasurementItem(BaseModel):
    weight_g: float
    remaining_ml: float
    drop_rate: float
    infusion_status: str
    measured_at: datetime


class MeasurementCreate(BaseModel):
    weight_g: float | None = None
    remaining_ml: float
    drop_rate: float
    infusion_status: str
    measured_at: datetime | None = None


class MeasurementBatchCreate(BaseModel):
    measurements: list[MeasurementCreate]


class MeasurementResponse(BaseModel):
    log_id: int
    remaining_ml: float
    drop_rate: float
    infusion_status: str
    measured_at: datetime

    class Config:
        from_attributes = True


class MeasurementBatchResponse(BaseModel):
    inserted_count: int
