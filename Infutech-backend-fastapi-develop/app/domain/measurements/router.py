from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.device_auth import get_device_from_headers
from app.domain.devices.model import Device
from app.domain.measurements.service import MeasurementService
from app.domain.measurements.schema import (
    MeasurementCreate,
    MeasurementResponse,
    MeasurementBatchCreate,
    MeasurementBatchResponse,
    AlertCreate,
    AlertResponse,
)

router = APIRouter()
alerts_router = APIRouter()


@router.post("", response_model=MeasurementResponse, status_code=status.HTTP_201_CREATED)
async def create_measurement(
    data: MeasurementCreate,
    device: Device = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db),
):
    service = MeasurementService(db)
    try:
        return await service.record_measurement(device, data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.post("/batch", response_model=MeasurementBatchResponse, status_code=status.HTTP_201_CREATED)
async def create_batch_measurement(
    data: MeasurementBatchCreate,
    device: Device = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db),
):
    service = MeasurementService(db)
    try:
        return await service.record_batch(device, data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@alerts_router.post("", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
async def create_device_alert(
    data: AlertCreate,
    device: Device = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db),
):
    service = MeasurementService(db)
    try:
        return await service.create_device_alert(device, data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
