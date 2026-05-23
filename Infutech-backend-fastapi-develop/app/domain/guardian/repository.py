from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.guardian.model import Guardian


class GuardianRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_guardian(self, patient_id: int) -> Guardian | None:
        result = await self.db.execute(
            select(Guardian).where(Guardian.patient_id == patient_id)
        )
        return result.scalars().first()

    async def save_guardian(
        self, patient_id: int, guardian_name: str, guardian_phone: str, relationship: str
    ) -> Guardian:
        guardian = await self.get_guardian(patient_id)
        if guardian:
            guardian.guardian_name = guardian_name
            guardian.guardian_phone = guardian_phone
            guardian.relationship = relationship
        else:
            guardian = Guardian(
                patient_id=patient_id,
                guardian_name=guardian_name,
                guardian_phone=guardian_phone,
                relationship=relationship,
            )
            self.db.add(guardian)
        await self.db.commit()
        await self.db.refresh(guardian)
        return guardian

    async def delete_guardian(self, patient_id: int) -> bool:
        guardian = await self.get_guardian(patient_id)
        if guardian:
            await self.db.delete(guardian)
            await self.db.commit()
            return True
        return False
