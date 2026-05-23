from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.settings.repository import SettingsRepository
from app.domain.settings.schema import SettingsResponse


class SettingsService:
    def __init__(self, db: AsyncSession):
        self.repository = SettingsRepository(db)

    async def get_settings(self, patient_id: int) -> SettingsResponse:
        settings = await self.repository.get_settings(patient_id)
        if not settings:
            settings = await self.repository.save_settings(patient_id, 100, True, True)
        return SettingsResponse.from_orm(settings)

    async def update_settings(
        self, patient_id: int, low_volume_threshold_ml: int, push_enabled: bool, vibration_enabled: bool
    ) -> SettingsResponse:
        settings = await self.repository.save_settings(
            patient_id, low_volume_threshold_ml, push_enabled, vibration_enabled
        )
        return SettingsResponse.from_orm(settings)
