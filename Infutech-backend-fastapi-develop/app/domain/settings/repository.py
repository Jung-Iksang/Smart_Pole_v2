from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.settings.model import Settings


class SettingsRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_settings(self, patient_id: int) -> Settings | None:
        result = await self.db.execute(
            select(Settings).where(Settings.patient_id == patient_id)
        )
        return result.scalars().first()

    async def save_settings(
        self, patient_id: int, low_volume_threshold_ml: int, push_enabled: bool, vibration_enabled: bool
    ) -> Settings:
        settings = await self.get_settings(patient_id)
        if settings:
            settings.low_volume_threshold_ml = low_volume_threshold_ml
            settings.push_enabled = push_enabled
            settings.vibration_enabled = vibration_enabled
        else:
            settings = Settings(
                patient_id=patient_id,
                low_volume_threshold_ml=low_volume_threshold_ml,
                push_enabled=push_enabled,
                vibration_enabled=vibration_enabled,
            )
            self.db.add(settings)
        await self.db.commit()
        await self.db.refresh(settings)
        return settings
