from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.profile.service import ProfileService
from app.domain.profile.schema import ProfileResponse, ProfileUpdateRequest, ProfileUpdateResponse

router = APIRouter()


@router.get("", response_model=ProfileResponse)
async def get_profile(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = ProfileService(db)
    try:
        return await service.get_profile(patient.patient_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.patch("", response_model=ProfileUpdateResponse)
async def update_profile(
    request: ProfileUpdateRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = ProfileService(db)
    try:
        return await service.update_profile(patient.patient_id, request.phone)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
