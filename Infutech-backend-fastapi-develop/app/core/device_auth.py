from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.domain.devices.model import Device


async def get_device_from_headers(
    x_device_serial: str = Header(...),
    x_device_key: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> Device:
    result = await db.execute(
        select(Device).where(Device.device_uid == x_device_serial)
    )
    device = result.scalars().first()

    if device is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="등록되지 않은 기기입니다",
        )

    if device.device_key and device.device_key != x_device_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="기기 인증에 실패했습니다",
        )

    return device
