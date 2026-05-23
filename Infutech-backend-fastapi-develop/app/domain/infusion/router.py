from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.infusion.service import InfusionService
from app.domain.infusion.schema import (
    CurrentInfusionResponse,
    InfusionHistoryResponse,
    InfusionSummaryResponse,
    InfusionSetupRequest,
    InfusionSetupResponse,
)

router = APIRouter()


@router.post("/setup", response_model=InfusionSetupResponse, status_code=status.HTTP_201_CREATED)
async def setup_infusion(
    device_id: int,
    data: InfusionSetupRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    """수액 정보 사전 설정 (용량, 약품명)"""
    service = InfusionService(db)
    return await service.setup_infusion(device_id, patient.patient_id, data)


@router.post("/acknowledge-completion")
async def acknowledge_completion(
    device_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    """수액 종료 확인 — 사용자가 종료를 확인하면 세션을 아카이브하고 수액 준비 화면으로 전환"""
    service = InfusionService(db)
    try:
        await service.acknowledge_completion(device_id)
        return {"success": True, "message": "수액 종료가 확인되었습니다"}
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.get("/current", response_model=CurrentInfusionResponse)
async def get_current_infusion(
    device_id: int,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = InfusionService(db)
    try:
        return await service.get_current_infusion(device_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.get("/history", response_model=InfusionHistoryResponse)
async def get_infusion_history(
    device_id: int,
    date: date | None = Query(None),
    page: int = Query(1),
    size: int = Query(10),
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = InfusionService(db)
    return await service.get_infusion_history(device_id, date, page, size)


@router.get("/summary", response_model=InfusionSummaryResponse)
async def get_infusion_summary(
    device_id: int,
    range: str = Query(...),
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = InfusionService(db)
    range_days = 7
    if range.endswith("d") and range[:-1].isdigit():
        range_days = int(range[:-1])
    return await service.get_infusion_summary(device_id, range_days)
