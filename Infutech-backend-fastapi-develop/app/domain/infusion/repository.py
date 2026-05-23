from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.infusion.model import DripSession, SensorLog


class InfusionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_latest_by_device(self, device_id: int) -> SensorLog | None:
        # 활성 세션의 최신 센서 로그
        result = await self.db.execute(
            select(SensorLog)
            .join(DripSession, DripSession.session_id == SensorLog.session_id)
            .where(SensorLog.device_id == device_id, DripSession.status == "running")
            .order_by(SensorLog.measured_at.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def get_active_session(self, device_id: int) -> DripSession | None:
        result = await self.db.execute(
            select(DripSession).where(
                DripSession.device_id == device_id,
                DripSession.status == "running",
            )
        )
        return result.scalars().first()

    async def get_completed_session(self, device_id: int) -> DripSession | None:
        """가장 최근 completed 세션 반환"""
        result = await self.db.execute(
            select(DripSession)
            .where(
                DripSession.device_id == device_id,
                DripSession.status == "completed",
            )
            .order_by(DripSession.created_at.desc())
            .limit(1)
        )
        return result.scalars().first()

    async def create_session(
        self,
        device_id: int,
        patient_id: int,
        total_ml: Optional[float] = None,
        fluid_name: Optional[str] = None,
    ) -> DripSession:
        session = DripSession(
            device_id=device_id,
            patient_id=patient_id,
            status="running",
            total_ml=total_ml,
            fluid_name=fluid_name,
        )
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)
        return session

    async def get_history(
        self, device_id: int, start_date: datetime | None, page: int, size: int
    ) -> tuple[list[SensorLog], int]:
        query = select(SensorLog).where(SensorLog.device_id == device_id)
        count_query = select(func.count()).select_from(SensorLog).where(SensorLog.device_id == device_id)

        if start_date:
            query = query.where(SensorLog.measured_at >= start_date)
            count_query = count_query.where(SensorLog.measured_at >= start_date)

        total_result = await self.db.execute(count_query)
        total = total_result.scalar() or 0

        result = await self.db.execute(
            query.order_by(SensorLog.measured_at.desc())
            .offset((page - 1) * size)
            .limit(size)
        )
        items = list(result.scalars().all())
        return items, total

    async def get_summary(self, device_id: int, range_days: int) -> dict:
        threshold = datetime.utcnow() - timedelta(days=range_days)
        result = await self.db.execute(
            select(SensorLog)
            .where(SensorLog.device_id == device_id, SensorLog.measured_at >= threshold)
        )
        records = list(result.scalars().all())

        if not records:
            return {"avg_drop_rate": 0.0, "min_remaining_ml": 0.0, "alert_count": 0}

        avg_drop_rate = sum(float(r.drop_rate) for r in records) / len(records)
        min_remaining_ml = min(float(r.remaining_ml) for r in records)
        alert_count = sum(1 for r in records if float(r.remaining_ml) < 50)

        return {
            "avg_drop_rate": round(avg_drop_rate, 2),
            "min_remaining_ml": round(min_remaining_ml, 2),
            "alert_count": alert_count,
        }
