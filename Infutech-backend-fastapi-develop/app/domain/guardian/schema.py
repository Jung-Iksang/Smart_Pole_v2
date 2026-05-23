from pydantic import BaseModel


class GuardianResponse(BaseModel):
    guardian_id: int
    guardian_name: str
    guardian_phone: str
    relationship: str

    class Config:
        from_attributes = True


class GuardianRequest(BaseModel):
    guardian_name: str
    guardian_phone: str
    relationship: str


class CommonResponse(BaseModel):
    success: bool
    message: str
