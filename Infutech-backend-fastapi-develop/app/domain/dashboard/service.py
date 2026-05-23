from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.dashboard.repository import DashboardRepository
from app.domain.dashboard.schema import DashboardResponse, DashboardPatient, DashboardDeviceItem


class DashboardService:
    def __init__(self, db: AsyncSession):
        self.repository = DashboardRepository(db)

    async def get_dashboard(self, patient_id: int) -> DashboardResponse:
        patient = await self.repository.get_patient(patient_id)
        if not patient:
            raise ValueError("환자 정보를 찾을 수 없습니다")

        devices = await self.repository.get_patient_devices(patient_id)
        items = []
        for device in devices:
            conn_status = await self.repository.get_patient_device_status(
                patient_id, device.device_id
            )
            # 세션 조회: running → completed → 없음 순서
            active_session = await self.repository.get_active_session(device.device_id)
            latest_session = await self.repository.get_latest_session(device.device_id)
            session = active_session or latest_session  # running 우선, 없으면 completed

            # infusion_status 결정:
            # - running 세션 + 로그 → 실시간 모니터링
            # - running 세션 + 로그 없음 → "waiting" (수액 정보 입력됨, 측정 대기)
            # - completed 세션 → "completed" (종료 확인 대기)
            # - 세션 없음 → "stopped" (수액 준비 대기)
            if active_session:
                latest_log = await self.repository.get_latest_sensor_log(device.device_id)
                if latest_log:
                    infusion_status = latest_log.infusion_status
                    remaining_ml = float(latest_log.remaining_ml)
                    drop_rate = float(latest_log.drop_rate)
                else:
                    infusion_status = "waiting"
                    remaining_ml = float(active_session.total_ml) if active_session.total_ml else 0.0
                    drop_rate = 0.0
            elif latest_session and latest_session.status == "completed":
                # 종료된 세션 — 사용자가 "종료 확인" 누를 때까지 표시
                infusion_status = "completed"
                remaining_ml = 0.0
                drop_rate = 0.0
            else:
                infusion_status = "stopped"
                remaining_ml = 0.0
                drop_rate = 0.0

            items.append(DashboardDeviceItem(
                device_id=device.device_id,
                device_name=device.device_name,
                connection_status=conn_status,
                remaining_ml=remaining_ml,
                drop_rate=drop_rate,
                infusion_status=infusion_status,
                total_ml=float(session.total_ml) if session and session.total_ml else None,
                fluid_name=session.fluid_name if session else None,
                battery_level=device.battery_level,
            ))

        return DashboardResponse(
            patient=DashboardPatient(name=patient.name),
            devices=items,
            unread_notification_count=await self.repository.get_unread_notification_count(patient_id),
        )
