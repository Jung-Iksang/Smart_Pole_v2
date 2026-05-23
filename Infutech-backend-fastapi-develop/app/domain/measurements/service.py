from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.websocket_manager import manager
from app.core.fcm import send_push_notification
from app.domain.devices.model import Device
from app.domain.measurements.repository import MeasurementRepository
from app.domain.measurements.schema import (
    MeasurementCreate,
    MeasurementResponse,
    MeasurementBatchCreate,
    MeasurementBatchResponse,
)


class MeasurementService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repository = MeasurementRepository(db)

    async def record_measurement(self, device: Device, data: MeasurementCreate) -> MeasurementResponse:
        # 디바이스에 연결된 환자 찾기
        patient_id = await self.repository.find_patient_id_for_device(device.device_id)
        if not patient_id:
            raise ValueError("기기에 연결된 환자가 없습니다")

        # 활성 세션 가져오거나 생성
        session = await self.repository.get_or_create_active_session(device.device_id, patient_id)

        # ── 팩 무게 보정 ──
        weight_g = data.weight_g or 0.0
        corrected_remaining = data.remaining_ml  # fallback: ESP32가 보낸 값

        # 1) 세션 첫 측정이면 initial_weight_g 저장
        if session.initial_weight_g is None and weight_g > 0:
            session.initial_weight_g = weight_g

        # 2) total_ml + initial_weight_g 있고 tare 아직 없으면 → tare 계산
        if (session.total_ml and session.initial_weight_g
                and session.tare_weight_g is None):
            session.tare_weight_g = float(session.initial_weight_g) - float(session.total_ml)

        # 3) tare가 있으면 보정된 remaining 계산
        if session.tare_weight_g is not None and weight_g > 0:
            total = float(session.total_ml) if session.total_ml else 500.0
            corrected_remaining = max(0.0, min(total, weight_g - float(session.tare_weight_g)))

        # 센서 로그 저장 (보정된 remaining_ml 사용)
        log = await self.repository.create_sensor_log(
            session_id=session.session_id,
            device_id=device.device_id,
            weight_g=data.weight_g,
            remaining_ml=corrected_remaining,
            drop_rate=data.drop_rate,
            infusion_status=data.infusion_status,
            measured_at=data.measured_at,
        )

        # 수액 종료 감지: stopped/completed → 세션 종료 처리
        if data.infusion_status in ("stopped", "completed"):
            session.status = "completed"
            session.ended_at = datetime.utcnow()
            # tare/initial 리셋 → 다음 수액팩 대비
            session.tare_weight_g = None
            session.initial_weight_g = None

        # 디바이스 last_seen_at 갱신
        device.last_seen_at = datetime.utcnow()
        device.network_status = "online"
        await self.db.commit()

        response = MeasurementResponse(
            log_id=log.log_id,
            remaining_ml=float(log.remaining_ml),
            drop_rate=float(log.drop_rate),
            infusion_status=log.infusion_status,
            measured_at=log.measured_at,
        )

        # WebSocket으로 실시간 브로드캐스트
        await manager.broadcast_to_device(device.device_id, response.model_dump(mode="json"))

        # 알림 트리거 체크
        await self._check_alerts(device, patient_id, data)

        return response

    async def _check_alerts(self, device: Device, patient_id: int, data: MeasurementCreate):
        """수액 상태에 따른 알림 트리거"""
        from sqlalchemy import select
        from app.domain.settings.model import Settings
        from app.domain.notifications.model import Notification
        from app.domain.auth.model import Patient, User

        # 환자 설정에서 임계값 조회
        result = await self.db.execute(
            select(Settings).where(Settings.patient_id == patient_id)
        )
        settings = result.scalars().first()
        threshold = settings.low_volume_threshold_ml if settings else 100

        alert_type = None
        title = None
        message = None

        if data.remaining_ml <= threshold and data.remaining_ml > 0:
            alert_type = "low_fluid"
            title = "수액 잔량 부족"
            message = f"수액 잔량이 {data.remaining_ml}ml로 부족합니다. 확인해주세요."
        elif data.drop_rate == 0 and data.infusion_status == "running":
            alert_type = "flow_stop"
            title = "수액 흐름 중단"
            message = "수액 흐름이 감지되지 않습니다. 기기를 확인해주세요."

        if alert_type:
            # 알림 DB 저장
            notification = Notification(
                patient_id=patient_id,
                device_id=device.device_id,
                type=alert_type,
                title=title,
                message=message,
            )
            self.db.add(notification)
            await self.db.commit()

            # FCM 푸시 전송
            result = await self.db.execute(
                select(User).join(Patient, Patient.user_id == User.user_id).where(
                    Patient.patient_id == patient_id
                )
            )
            user = result.scalars().first()
            if user and user.fcm_token and settings and settings.push_enabled:
                await send_push_notification(user.fcm_token, title, message)

    async def record_batch(self, device: Device, data: MeasurementBatchCreate) -> MeasurementBatchResponse:
        patient_id = await self.repository.find_patient_id_for_device(device.device_id)
        if not patient_id:
            raise ValueError("기기에 연결된 환자가 없습니다")

        session = await self.repository.get_or_create_active_session(device.device_id, patient_id)

        count = 0
        for measurement in data.measurements:
            await self.repository.create_sensor_log(
                session_id=session.session_id,
                device_id=device.device_id,
                weight_g=measurement.weight_g,
                remaining_ml=measurement.remaining_ml,
                drop_rate=measurement.drop_rate,
                infusion_status=measurement.infusion_status,
                measured_at=measurement.measured_at,
            )
            count += 1

        device.last_seen_at = datetime.utcnow()
        device.network_status = "online"
        await self.db.commit()

        return MeasurementBatchResponse(inserted_count=count)
