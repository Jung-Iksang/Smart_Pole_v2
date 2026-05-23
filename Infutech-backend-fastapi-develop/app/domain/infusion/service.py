from __future__ import annotations

from datetime import date, datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.infusion.repository import InfusionRepository
from app.domain.infusion.schema import (
    CurrentInfusionResponse,
    InfusionHistoryResponse,
    InfusionHistoryItem,
    InfusionSummaryResponse,
    InfusionSetupRequest,
    InfusionSetupResponse,
)


class InfusionService:
    def __init__(self, db: AsyncSession):
        self.repository = InfusionRepository(db)

    async def get_current_infusion(self, device_id: int) -> CurrentInfusionResponse:
        record = await self.repository.get_latest_by_device(device_id)
        if not record:
            raise ValueError("수액 기록을 찾을 수 없습니다")
        return CurrentInfusionResponse(
            device_id=record.device_id,
            session_id=record.session_id,
            remaining_ml=float(record.remaining_ml),
            drop_rate=float(record.drop_rate),
            infusion_status=record.infusion_status,
            measured_at=record.measured_at,
        )

    async def get_infusion_history(
        self, device_id: int, filter_date: date | None, page: int, size: int
    ) -> InfusionHistoryResponse:
        start_date = None
        if filter_date is not None:
            start_date = datetime(filter_date.year, filter_date.month, filter_date.day)
        items, total = await self.repository.get_history(device_id, start_date, page, size)
        return InfusionHistoryResponse(
            items=[
                InfusionHistoryItem(
                    measured_at=item.measured_at,
                    remaining_ml=float(item.remaining_ml),
                    drop_rate=float(item.drop_rate),
                    infusion_status=item.infusion_status,
                )
                for item in items
            ],
            page=page,
            size=size,
            total=total,
        )

    async def get_infusion_summary(self, device_id: int, range_days: int) -> InfusionSummaryResponse:
        summary = await self.repository.get_summary(device_id, range_days)
        return InfusionSummaryResponse(**summary)

    async def acknowledge_completion(self, device_id: int) -> bool:
        """수액 종료 확인 — completed/running 세션을 모두 archived로 변경"""
        # completed 세션 아카이브
        completed = await self.repository.get_completed_session(device_id)
        if completed:
            completed.status = "archived"

        # ESP32가 자동 생성한 빈 running 세션도 정리
        active = await self.repository.get_active_session(device_id)
        if active:
            active.status = "archived"

        if not completed and not active:
            raise ValueError("정리할 세션이 없습니다")

        await self.repository.db.commit()
        return True

    async def setup_infusion(
        self, device_id: int, patient_id: int, data: InfusionSetupRequest
    ) -> InfusionSetupResponse:
        """수액 정보 사전 설정 — 세션을 미리 생성하거나 기존 세션에 정보 업데이트"""
        session = await self.repository.get_active_session(device_id)
        if session:
            # 기존 활성 세션에 수액 정보 업데이트
            session.total_ml = data.total_ml
            session.fluid_name = data.fluid_name
            # tare 리셋 → 다음 측정에서 재계산
            session.tare_weight_g = None
            # initial_weight_g가 이미 있으면 바로 tare 재계산
            if session.initial_weight_g is not None:
                session.tare_weight_g = float(session.initial_weight_g) - data.total_ml
            await self.repository.db.commit()
            await self.repository.db.refresh(session)
        else:
            # 새 세션 생성 (수액이 걸리기 전 사전 설정)
            session = await self.repository.create_session(
                device_id=device_id,
                patient_id=patient_id,
                total_ml=data.total_ml,
                fluid_name=data.fluid_name,
            )
        return InfusionSetupResponse(
            session_id=session.session_id,
            device_id=device_id,
            total_ml=float(session.total_ml) if session.total_ml else 0.0,
            fluid_name=session.fluid_name,
            status=session.status,
        )
