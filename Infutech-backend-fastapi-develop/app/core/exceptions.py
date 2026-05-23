from fastapi import Request, status
from fastapi.responses import JSONResponse


class AppException(Exception):
    def __init__(self, detail: str, status_code: int = 400):
        self.detail = detail
        self.status_code = status_code


class NotFoundError(AppException):
    def __init__(self, detail: str = "리소스를 찾을 수 없습니다"):
        super().__init__(detail=detail, status_code=status.HTTP_404_NOT_FOUND)


class AuthenticationError(AppException):
    def __init__(self, detail: str = "인증에 실패했습니다"):
        super().__init__(detail=detail, status_code=status.HTTP_401_UNAUTHORIZED)


class ForbiddenError(AppException):
    def __init__(self, detail: str = "접근 권한이 없습니다"):
        super().__init__(detail=detail, status_code=status.HTTP_403_FORBIDDEN)


async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )
