from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.exceptions import AppException, app_exception_handler
from app.database import engine, Base

# 모든 모델을 임포트해서 Base.metadata에 등록
from app.domain.auth.model import User, Patient, PatientDevice  # noqa: F401
from app.domain.devices.model import Device  # noqa: F401
from app.domain.infusion.model import DripSession, SensorLog  # noqa: F401
from app.domain.notifications.model import Notification  # noqa: F401
from app.domain.guardian.model import Guardian  # noqa: F401
from app.domain.settings.model import Settings  # noqa: F401

from app.domain.auth.router import router as auth_router
from app.domain.devices.router import router as devices_router
from app.domain.infusion.router import router as infusion_router
from app.domain.notifications.router import router as notifications_router
from app.domain.profile.router import router as profile_router
from app.domain.guardian.router import router as guardian_router
from app.domain.settings.router import router as settings_router
from app.domain.account.router import router as account_router
from app.domain.dashboard.router import router as dashboard_router
from app.domain.measurements.router import router as measurements_router
from app.domain.ota.router import router as ota_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 개발용: 테이블 자동 생성 (프로덕션에서는 Alembic 사용)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="Smart Ringer API",
    description="IoT 수액 모니터링 시스템 백엔드",
    version="2.0.0",
    lifespan=lifespan,
)

# 글로벌 예외 핸들러
app.add_exception_handler(AppException, app_exception_handler)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(devices_router, prefix="/api/v1/devices", tags=["Devices"])
app.include_router(infusion_router, prefix="/api/v1/devices/{device_id}/infusion", tags=["Infusion"])
app.include_router(notifications_router, prefix="/api/v1/notifications", tags=["Notifications"])
app.include_router(profile_router, prefix="/api/v1/profile", tags=["Profile"])
app.include_router(guardian_router, prefix="/api/v1/guardian", tags=["Guardian"])
app.include_router(settings_router, prefix="/api/v1/settings", tags=["Settings"])
app.include_router(account_router, prefix="/api/v1/account", tags=["Account"])
app.include_router(dashboard_router, prefix="/api/v1/dashboard", tags=["Dashboard"])
app.include_router(measurements_router, prefix="/api/v1/measurements", tags=["Measurements"])
app.include_router(ota_router, prefix="/api/v1/ota", tags=["OTA"])


# --- WebSocket 실시간 스트리밍 ---

from app.core.websocket_manager import manager
from app.core.security import decode_token
from app.database import async_session
from sqlalchemy import select


@app.websocket("/api/v1/measurements/{device_id}/realtime")
async def websocket_realtime(websocket: WebSocket, device_id: int, token: str = Query(...)):
    # JWT 인증
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001, reason="인증 실패")
        return

    user_id = int(payload["sub"])

    # 사용자가 해당 기기에 접근 권한이 있는지 확인
    async with async_session() as db:
        result = await db.execute(
            select(PatientDevice).join(Patient, Patient.patient_id == PatientDevice.patient_id).where(
                Patient.user_id == user_id,
                PatientDevice.device_id == device_id,
            )
        )
        if not result.scalars().first():
            await websocket.close(code=4003, reason="기기 접근 권한이 없습니다")
            return

    await manager.connect(device_id, websocket)
    try:
        while True:
            # 클라이언트로부터 ping 대기 (연결 유지용)
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(device_id, websocket)
