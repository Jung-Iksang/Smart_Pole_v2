from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.guardian.service import GuardianService
from app.domain.guardian.schema import GuardianResponse, GuardianRequest, CommonResponse

router = APIRouter()


@router.get("", response_model=GuardianResponse)
async def get_guardian(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = GuardianService(db)
    try:
        return await service.get_guardian(patient.patient_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.put("", response_model=GuardianResponse)
async def update_guardian(
    request: GuardianRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = GuardianService(db)
    return await service.save_guardian(
        patient.patient_id, request.guardian_name, request.guardian_phone, request.relationship
    )


@router.delete("", response_model=CommonResponse)
async def delete_guardian(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = GuardianService(db)
    try:
        return await service.delete_guardian(patient.patient_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
