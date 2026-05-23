from __future__ import annotations

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.auth.model import Patient, PatientDevice
from app.domain.devices.model import Device
from app.domain.infusion.model import DripSession, SensorLog
from app.domain.notifications.model import Notification


class DashboardRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_patient(self, patient_id: int) -> Patient | None:
        result = await self.db.execute(
            select(Patient).where(Patient.patient_id == patient_id)
        )
        return result.scalars().first()

    async def get_patient_devices(self, patient_id: int) -> list[Device]:
        result = await self.db.execute(
            select(Device)
            .join(PatientDevice, PatientDevice.device_id == Device.device_id)
            .where(PatientDevice.patient_id == patient_id)
        )
        return list(result.scalars().all())

    async def get_patient_device_status(self, patient_id: int, device_id: int) -> str:
        result = await self.db.execute(
            select(PatientDevice.connection_status).where(
                PatientDevice.patient_id == patient_id,
                PatientDevice.device_id == device_id,
            )
        )
        status = result.scalar()
        return status or "disconnected"

    async def get_latest_sensor_log(self, device_id: int) -> SensorLog | None:
        # 가장 최근 세션(running 또는 completed)의 최신 로그
        session = await self.get_latest_session(device_id)
        if not session:
            return None
        result = await self.db.execute(
            select(SensorLog)
            .where(
                SensorLog.device_id == device_id,
                SensorLog.session_id == session.session_id,
            )
            .order_by(SensorLog.measured_at.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def get_active_session(self, device_id: int) -> DripSession | None:
        """running 상태인 세션만 반환"""
        result = await self.db.execute(
            select(DripSession).where(
                DripSession.device_id == device_id,
                DripSession.status == "running",
            )
        )
        return result.scalars().first()

    async def get_latest_session(self, device_id: int) -> DripSession | None:
        """가장 최근 세션 반환 (running 또는 completed)"""
        result = await self.db.execute(
            select(DripSession)
            .where(
                DripSession.device_id == device_id,
                DripSession.status.in_(["running", "completed"]),
            )
            .order_by(DripSession.created_at.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def get_unread_notification_count(self, patient_id: int) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Notification).where(
                Notification.patient_id == patient_id,
                Notification.is_read == False,
            )
        )
        return result.scalar() or 0
