from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_patient
from app.domain.auth.model import Patient
from app.domain.account.service import AccountService
from app.domain.account.schema import WithdrawalCheckResponse, AccountDeleteRequest, CommonResponse

router = APIRouter()


@router.get("/withdrawal-check", response_model=WithdrawalCheckResponse)
async def get_withdrawal_check(
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    service = AccountService(db)
    return await service.get_withdrawal_check(patient.patient_id)


@router.delete("", response_model=CommonResponse)
async def delete_account(
    request: AccountDeleteRequest,
    patient: Patient = Depends(get_current_patient),
    db: AsyncSession = Depends(get_db),
):
    # 생년월일 재확인
    if patient.birth_date != request.birth_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="생년월일이 일치하지 않습니다",
        )
    service = AccountService(db)
    try:
        return await service.delete_account(patient.patient_id, request.birth_date)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
