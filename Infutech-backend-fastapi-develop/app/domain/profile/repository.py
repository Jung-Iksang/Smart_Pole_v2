from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.auth.model import Patient


class ProfileRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_patient(self, patient_id: int) -> Patient | None:
        result = await self.db.execute(
            select(Patient).where(Patient.patient_id == patient_id)
        )
        return result.scalars().first()

    async def update_phone(self, patient_id: int, phone: str) -> Patient | None:
        patient = await self.get_patient(patient_id)
        if patient:
            patient.phone = phone
            await self.db.commit()
            await self.db.refresh(patient)
        return patient
