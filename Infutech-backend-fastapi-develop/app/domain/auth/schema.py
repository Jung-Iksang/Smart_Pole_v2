from __future__ import annotations

from pydantic import BaseModel
from datetime import date


# --- Auth Request/Response ---

class SignupRequest(BaseModel):
    username: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class TokenRefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# --- Patient Verification ---

class PatientVerifyRequest(BaseModel):
    patient_code: str
    birth_date: date


class PatientInfo(BaseModel):
    patient_id: int
    patient_code: str
    name: str

    class Config:
        from_attributes = True


class PatientVerifyResponse(BaseModel):
    patient: PatientInfo


# --- OAuth ---

class OAuthRequest(BaseModel):
    access_token: str  # OAuth provider access token


# --- User Info ---

class UserInfo(BaseModel):
    user_id: int
    username: str

    class Config:
        from_attributes = True


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserInfo
    patient: PatientInfo | None = None


class SignupResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserInfo


# --- Logout ---

class LogoutResponse(BaseModel):
    success: bool
    message: str


# --- FCM Token ---

class FcmTokenRequest(BaseModel):
    fcm_token: str
