from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.account.repository import AccountRepository
from app.domain.account.schema import WithdrawalCheckResponse, CommonResponse


class AccountService:
    def __init__(self, db: AsyncSession):
        self.repository = AccountRepository(db)

    async def get_withdrawal_check(self, patient_id: int) -> WithdrawalCheckResponse:
        return WithdrawalCheckResponse(
            has_connected_devices=await self.repository.has_connected_devices(patient_id),
            has_guardian=await self.repository.has_guardian(patient_id),
            unread_notification_count=await self.repository.unread_notification_count(patient_id),
        )

    async def delete_account(self, patient_id: int, birth_date) -> CommonResponse:
        deleted = await self.repository.soft_delete_patient(patient_id)
        if not deleted:
            raise ValueError("계정 삭제에 실패했습니다")
        return CommonResponse(success=True, message="계정이 삭제되었습니다")
