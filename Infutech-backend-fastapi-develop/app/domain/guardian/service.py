from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.guardian.repository import GuardianRepository
from app.domain.guardian.schema import GuardianResponse, CommonResponse


class GuardianService:
    def __init__(self, db: AsyncSession):
        self.repository = GuardianRepository(db)

    async def get_guardian(self, patient_id: int) -> GuardianResponse:
        guardian = await self.repository.get_guardian(patient_id)
        if not guardian:
            raise ValueError("보호자 정보를 찾을 수 없습니다")
        return GuardianResponse.from_orm(guardian)

    async def save_guardian(
        self, patient_id: int, guardian_name: str, guardian_phone: str, relationship: str
    ) -> GuardianResponse:
        guardian = await self.repository.save_guardian(
            patient_id, guardian_name, guardian_phone, relationship
        )
        return GuardianResponse.from_orm(guardian)

    async def delete_guardian(self, patient_id: int) -> CommonResponse:
        deleted = await self.repository.delete_guardian(patient_id)
        if not deleted:
            raise ValueError("보호자 정보를 찾을 수 없습니다")
        return CommonResponse(success=True, message="보호자 정보가 삭제되었습니다")
