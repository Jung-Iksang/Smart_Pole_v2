from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token
from app.domain.auth.repository import AuthRepository
from app.domain.auth.schema import (
    SignupRequest, SignupResponse,
    LoginRequest, LoginResponse,
    TokenRefreshRequest, TokenRefreshResponse,
    PatientVerifyRequest, PatientVerifyResponse,
    LogoutResponse, PatientInfo, UserInfo,
)
from app.domain.auth.model import User


class AuthService:
    def __init__(self, db: AsyncSession):
        self.repository = AuthRepository(db)

    async def signup(self, request: SignupRequest) -> SignupResponse:
        existing = await self.repository.find_user_by_username(request.username)
        if existing:
            raise ValueError("이미 사용 중인 아이디입니다")

        hashed = hash_password(request.password)
        user = await self.repository.create_user(username=request.username, hashed_password=hashed)

        # 사용자와 연결된 Patient 자동 생성
        await self.repository.create_default_patient(user)

        access_token = create_access_token(user.user_id)
        refresh_token = create_refresh_token(user.user_id)

        return SignupResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserInfo(user_id=user.user_id, username=user.username),
        )

    async def login(self, request: LoginRequest) -> LoginResponse:
        user = await self.repository.find_user_by_username(request.username)
        if not user or not verify_password(request.password, user.hashed_password):
            raise ValueError("아이디 또는 비밀번호가 올바르지 않습니다")

        if not user.is_active:
            raise ValueError("비활성화된 계정입니다")

        access_token = create_access_token(user.user_id)
        refresh_token = create_refresh_token(user.user_id)

        # 연결된 Patient가 있으면 함께 반환
        patient = await self.repository.find_patient_by_user_id(user.user_id)
        patient_info = None
        if patient:
            patient_info = PatientInfo(
                patient_id=patient.patient_id,
                patient_code=patient.patient_code,
                name=patient.name,
            )

        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserInfo(user_id=user.user_id, username=user.username),
            patient=patient_info,
        )

    async def refresh_token(self, request: TokenRefreshRequest) -> TokenRefreshResponse:
        payload = decode_token(request.refresh_token)
        if payload is None or payload.get("type") != "refresh":
            raise ValueError("유효하지 않은 리프레시 토큰입니다")

        user_id = int(payload["sub"])
        user = await self.repository.find_user_by_id(user_id)
        if not user or not user.is_active:
            raise ValueError("사용자를 찾을 수 없습니다")

        access_token = create_access_token(user.user_id)
        return TokenRefreshResponse(access_token=access_token)

    async def verify_patient(self, user: User, request: PatientVerifyRequest) -> PatientVerifyResponse:
        patient = await self.repository.find_patient(request.patient_code, request.birth_date)
        if not patient:
            raise ValueError("환자 정보를 찾을 수 없습니다. 환자 코드와 생년월일을 확인해주세요.")

        if patient.user_id and patient.user_id != user.user_id:
            raise ValueError("이미 다른 계정에 연결된 환자입니다")

        if not patient.user_id:
            patient = await self.repository.link_patient_to_user(patient, user.user_id)

        return PatientVerifyResponse(
            patient=PatientInfo(
                patient_id=patient.patient_id,
                patient_code=patient.patient_code,
                name=patient.name,
            )
        )

    async def update_fcm_token(self, user_id: int, fcm_token: str) -> None:
        await self.repository.update_fcm_token(user_id, fcm_token)

    async def logout(self) -> LogoutResponse:
        return LogoutResponse(success=True, message="로그아웃 되었습니다")
