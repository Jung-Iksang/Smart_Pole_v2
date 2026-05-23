from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.auth.model import Patient, PatientDevice
from app.domain.guardian.model import Guardian
from app.domain.notifications.model import Notification


class AccountRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def has_connected_devices(self, patient_id: int) -> bool:
        result = await self.db.execute(
            select(func.count()).select_from(PatientDevice).where(
                PatientDevice.patient_id == patient_id,
                PatientDevice.connection_status == "connected",
            )
        )
        return (result.scalar() or 0) > 0

    async def has_guardian(self, patient_id: int) -> bool:
        result = await self.db.execute(
            select(func.count()).select_from(Guardian).where(
                Guardian.patient_id == patient_id
            )
        )
        return (result.scalar() or 0) > 0

    async def unread_notification_count(self, patient_id: int) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Notification).where(
                Notification.patient_id == patient_id,
                Notification.is_read == False,
            )
        )
        return result.scalar() or 0

    async def soft_delete_patient(self, patient_id: int) -> bool:
        result = await self.db.execute(
            select(Patient).where(Patient.patient_id == patient_id)
        )
        patient = result.scalars().first()
        if patient:
            patient.is_deleted = True
            from datetime import datetime
            patient.deleted_at = datetime.utcnow()
            patient.is_active = False
            await self.db.commit()
            return True
        return False
