from __future__ import annotations

from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.auth.model import User, Patient


class AuthRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    # --- User ---

    async def find_user_by_username(self, username: str) -> User | None:
        result = await self.db.execute(select(User).where(User.username == username))
        return result.scalars().first()

    async def find_user_by_id(self, user_id: int) -> User | None:
        result = await self.db.execute(select(User).where(User.user_id == user_id))
        return result.scalars().first()

    async def create_user(self, username: str, hashed_password: str, oauth_provider: str | None = None, oauth_provider_id: str | None = None) -> User:
        user = User(
            username=username,
            hashed_password=hashed_password,
            oauth_provider=oauth_provider,
            oauth_provider_id=oauth_provider_id,
        )
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        return user

    async def create_default_patient(self, user: User) -> Patient:
        """회원가입 시 사용자와 연결된 기본 Patient 레코드 자동 생성"""
        patient = Patient(
            user_id=user.user_id,
            patient_code=f"U-{user.user_id}",
            name=user.username,
            birth_date=date(2000, 1, 1),
            is_active=True,
            is_verified=True,
            is_deleted=False,
        )
        self.db.add(patient)
        await self.db.commit()
        await self.db.refresh(patient)
        return patient

    async def update_fcm_token(self, user_id: int, fcm_token: str) -> None:
        user = await self.find_user_by_id(user_id)
        if user:
            user.fcm_token = fcm_token
            await self.db.commit()

    # --- Patient ---

    async def find_patient(self, patient_code: str, birth_date: date) -> Patient | None:
        result = await self.db.execute(
            select(Patient).where(
                Patient.patient_code == patient_code,
                Patient.birth_date == birth_date,
                Patient.is_deleted == False,
            )
        )
        return result.scalars().first()

    async def find_patient_by_user_id(self, user_id: int) -> Patient | None:
        result = await self.db.execute(
            select(Patient).where(Patient.user_id == user_id, Patient.is_deleted == False)
        )
        return result.scalars().first()

    async def link_patient_to_user(self, patient: Patient, user_id: int) -> Patient:
        patient.user_id = user_id
        patient.is_verified = True
        await self.db.commit()
        await self.db.refresh(patient)
        return patient
