from __future__ import annotations

from datetime import date
from pydantic import BaseModel


class ProfileResponse(BaseModel):
    patient_id: int
    patient_code: str
    name: str
    birth_date: date
    phone: str | None

    class Config:
        from_attributes = True


class ProfileUpdateRequest(BaseModel):
    phone: str


class ProfileUpdateResponse(BaseModel):
    patient_id: int
    phone: str

    class Config:
        from_attributes = True
