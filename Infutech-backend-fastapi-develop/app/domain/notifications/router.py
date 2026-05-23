from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.notifications.service import NotificationService
from app.domain.notifications.schema import (
    NotificationListResponse,
    NotificationDetailResponse,
    NotificationReadResponse,
    CommonResponse,
)

router = APIRouter()


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    page: int = Query(1),
    size: int = Query(10),
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    return await service.get_notifications(patient.patient_id, page, size)


@router.get("/{notification_id}", response_model=NotificationDetailResponse)
async def get_notification(
    notification_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    try:
        return await service.get_notification(notification_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.patch("/{notification_id}/read", response_model=NotificationReadResponse)
async def read_notification(
    notification_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    try:
        return await service.read_notification(notification_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.patch("/read-all", response_model=CommonResponse)
async def read_all_notifications(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = NotificationService(db)
    return await service.read_all_notifications(patient.patient_id)
