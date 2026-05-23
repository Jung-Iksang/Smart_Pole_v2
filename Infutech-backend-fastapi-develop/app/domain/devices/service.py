from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.devices.repository import DeviceRepository
from app.domain.devices.schema import (
    DeviceItem,
    RegisterDeviceRequest,
    RegisterDeviceResponse,
    ConnectionStatusResponse,
    DeviceDetailResponse,
)


class DeviceService:
    def __init__(self, db: AsyncSession):
        self.repository = DeviceRepository(db)

    async def list_devices(self, patient_id: int) -> list[DeviceItem]:
        devices = await self.repository.get_devices_by_patient(patient_id)
        result = []
        for device in devices:
            pd = await self.repository.find_patient_device(patient_id, device.device_id)
            result.append(DeviceItem(
                device_id=device.device_id,
                device_name=device.device_name,
                device_uid=device.device_uid,
                connection_status=pd.connection_status if pd else "disconnected",
                battery_level=device.battery_level,
                last_seen_at=device.last_seen_at,
            ))
        return result

    async def register_device(self, patient_id: int, request: RegisterDeviceRequest) -> RegisterDeviceResponse:
        existing = await self.repository.find_by_qr_code(request.qr_code_value)

        if existing:
            # 기기가 이미 존재하면, 현재 환자와 연결만 추가
            pd = await self.repository.find_patient_device(patient_id, existing.device_id)
            if pd:
                raise ValueError("이미 연결된 기기입니다")
            await self.repository.create_patient_device(patient_id, existing.device_id)
            return RegisterDeviceResponse(
                device_id=existing.device_id,
                device_name=existing.device_name,
                connection_status="connected",
            )

        device = await self.repository.create_device(request.qr_code_value)
        await self.repository.create_patient_device(patient_id, device.device_id)
        return RegisterDeviceResponse(
            device_id=device.device_id,
            device_name=device.device_name,
            connection_status="connected",
        )

    async def get_connection_status(self, patient_id: int, device_id: int) -> ConnectionStatusResponse:
        device = await self.repository.find_by_id(device_id)
        if not device:
            raise ValueError("기기를 찾을 수 없습니다")
        conn_status = await self.repository.get_connection_status(patient_id, device_id)
        return ConnectionStatusResponse(
            device_id=device.device_id,
            connection_status=conn_status,
            last_seen_at=device.last_seen_at,
        )

    async def get_device_detail(self, device_id: int) -> DeviceDetailResponse:
        device = await self.repository.find_by_id(device_id)
        if not device:
            raise ValueError("기기를 찾을 수 없습니다")
        return DeviceDetailResponse(
            device_id=device.device_id,
            device_name=device.device_name,
            device_uid=device.device_uid,
            battery_level=device.battery_level,
            network_status=device.network_status,
            last_seen_at=device.last_seen_at,
        )

    async def delete_device(self, patient_id: int, device_id: int) -> bool:
        deleted = await self.repository.delete_patient_device(patient_id, device_id)
        if not deleted:
            raise ValueError("기기를 찾을 수 없습니다")
        # 해당 기기의 모든 세션 정리 (다시 연결 시 깨끗한 상태)
        await self.repository.cleanup_device_sessions(device_id)
        return True
