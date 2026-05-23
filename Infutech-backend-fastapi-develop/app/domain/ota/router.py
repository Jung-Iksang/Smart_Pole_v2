from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.device_auth import get_device_from_headers
from app.domain.devices.model import Device

router = APIRouter()


class OtaCheckResponse(BaseModel):
    update_available: bool
    version: str
    download_url: str


CURRENT_FIRMWARE_VERSION = "1.0.0"


@router.get("/check", response_model=OtaCheckResponse)
async def check_ota(device: Device = Depends(get_device_from_headers)):
    return OtaCheckResponse(
        update_available=False,
        version=CURRENT_FIRMWARE_VERSION,
        download_url="",
    )
