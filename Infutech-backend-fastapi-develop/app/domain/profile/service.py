from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.profile.repository import ProfileRepository
from app.domain.profile.schema import ProfileResponse, ProfileUpdateResponse


class ProfileService:
    def __init__(self, db: AsyncSession):
        self.repository = ProfileRepository(db)

    async def get_profile(self, patient_id: int) -> ProfileResponse:
        patient = await self.repository.get_patient(patient_id)
        if not patient:
            raise ValueError("환자 정보를 찾을 수 없습니다")
        return ProfileResponse.from_orm(patient)

    async def update_profile(self, patient_id: int, phone: str) -> ProfileUpdateResponse:
        updated = await self.repository.update_phone(patient_id, phone)
        if not updated:
            raise ValueError("전화번호 업데이트에 실패했습니다")
        return ProfileUpdateResponse.from_orm(updated)
