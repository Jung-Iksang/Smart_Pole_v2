from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.deps import get_current_user
from app.domain.auth.model import User
from app.domain.auth.schema import (
    SignupRequest, SignupResponse,
    LoginRequest, LoginResponse,
    TokenRefreshRequest, TokenRefreshResponse,
    PatientVerifyRequest, PatientVerifyResponse,
    LogoutResponse, FcmTokenRequest,
)
from app.domain.auth.service import AuthService

router = APIRouter()


@router.post("/signup", response_model=SignupResponse, status_code=status.HTTP_201_CREATED)
async def signup(request: SignupRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    try:
        return await service.signup(request)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    try:
        return await service.login(request)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))


@router.post("/refresh", response_model=TokenRefreshResponse)
async def refresh_token(request: TokenRefreshRequest, db: AsyncSession = Depends(get_db)):
    service = AuthService(db)
    try:
        return await service.refresh_token(request)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))


@router.post("/verify-patient", response_model=PatientVerifyResponse)
async def verify_patient(
    request: PatientVerifyRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    try:
        return await service.verify_patient(user, request)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/logout", response_model=LogoutResponse)
async def logout(user: User = Depends(get_current_user)):
    return LogoutResponse(success=True, message="로그아웃 되었습니다")


@router.post("/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
async def update_fcm_token(
    request: FcmTokenRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    await service.update_fcm_token(user.user_id, request.fcm_token)


@router.post("/oauth/kakao", response_model=LoginResponse)
async def oauth_kakao(db: AsyncSession = Depends(get_db)):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="카카오 OAuth 로그인은 아직 준비 중입니다",
    )


@router.post("/oauth/google", response_model=LoginResponse)
async def oauth_google(db: AsyncSession = Depends(get_db)):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="구글 OAuth 로그인은 아직 준비 중입니다",
    )
