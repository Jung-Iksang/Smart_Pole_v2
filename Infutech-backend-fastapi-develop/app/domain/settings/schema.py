from pydantic import BaseModel


class SettingsResponse(BaseModel):
    low_volume_threshold_ml: int
    push_enabled: bool
    vibration_enabled: bool

    class Config:
        from_attributes = True


class SettingsUpdateRequest(BaseModel):
    low_volume_threshold_ml: int
    push_enabled: bool
    vibration_enabled: bool
