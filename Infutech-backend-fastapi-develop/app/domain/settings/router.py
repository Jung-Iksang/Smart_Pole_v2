from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.settings.service import SettingsService
from app.domain.settings.schema import SettingsResponse, SettingsUpdateRequest

router = APIRouter()


@router.get("", response_model=SettingsResponse)
async def get_settings(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = SettingsService(db)
    return await service.get_settings(patient.patient_id)


@router.put("", response_model=SettingsResponse)
async def update_settings(
    request: SettingsUpdateRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = SettingsService(db)
    return await service.update_settings(
        patient.patient_id,
        request.low_volume_threshold_ml,
        request.push_enabled,
        request.vibration_enabled,
    )
