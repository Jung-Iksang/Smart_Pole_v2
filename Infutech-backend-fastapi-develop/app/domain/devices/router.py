from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.core.device_auth import get_device_from_headers
from app.domain.auth.model import Patient
from app.domain.devices.model import Device
from app.domain.devices.service import DeviceService
from app.domain.devices.schema import (
    DeviceItem,
    RegisterDeviceRequest,
    RegisterDeviceResponse,
    ConnectionStatusResponse,
    DeviceDetailResponse,
    CommonResponse,
)

router = APIRouter()


@router.get("", response_model=list[DeviceItem])
async def list_devices(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = DeviceService(db)
    return await service.list_devices(patient.patient_id)


@router.post("/register", response_model=RegisterDeviceResponse)
async def register_device(
    request: RegisterDeviceRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = DeviceService(db)
    try:
        return await service.register_device(patient.patient_id, request)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("/{device_id}/connection-status", response_model=ConnectionStatusResponse)
async def connection_status(
    device_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = DeviceService(db)
    try:
        return await service.get_connection_status(patient.patient_id, device_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.get("/{device_id}", response_model=DeviceDetailResponse)
async def get_device(
    device_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = DeviceService(db)
    try:
        return await service.get_device_detail(device_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.delete("/{device_id}", response_model=CommonResponse)
async def delete_device(
    device_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = DeviceService(db)
    try:
        await service.delete_device(patient.patient_id, device_id)
        return CommonResponse(success=True, message="기기 연결이 해제되었습니다")
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.post("/{device_id}/heartbeat", status_code=status.HTTP_204_NO_CONTENT)
async def heartbeat(
    device_id: int,
    device: Device = Depends(get_device_from_headers),
    db: AsyncSession = Depends(get_db),
):
    """ESP32 기기 하트비트 (1분 간격). last_seen_at 갱신."""
    service = DeviceService(db)
    await service.repository.update_last_seen(device_id)
