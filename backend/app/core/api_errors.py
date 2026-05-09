from __future__ import annotations

from dataclasses import dataclass

from fastapi import HTTPException, status
from fastapi.responses import JSONResponse

from app.core.messages import Messages


def error_payload(code: str, message: str) -> dict[str, str]:
    return {
        "code": code,
        "message": message,
    }


@dataclass(slots=True)
class ApiError(Exception):
    status_code: int
    code: str
    message: str

    def to_payload(self) -> dict[str, str]:
        return error_payload(self.code, self.message)


def _default_http_error_code(status_code: int) -> str:
    mapping = {
        status.HTTP_400_BAD_REQUEST: "bad_request",
        status.HTTP_401_UNAUTHORIZED: "unauthorized",
        status.HTTP_403_FORBIDDEN: "forbidden",
        status.HTTP_404_NOT_FOUND: "not_found",
        status.HTTP_409_CONFLICT: "conflict",
        status.HTTP_410_GONE: "gone",
    }
    return mapping.get(status_code, "http_error")


def normalize_http_exception(exc: HTTPException) -> dict[str, str]:
    detail = exc.detail
    if isinstance(detail, dict):
        code = str(detail.get("code") or _default_http_error_code(exc.status_code))
        message = str(detail.get("message") or Messages.HTTP_ERROR)
        return error_payload(code, message)

    if isinstance(detail, str):
        return error_payload(_default_http_error_code(exc.status_code), detail)

    return error_payload(_default_http_error_code(exc.status_code), Messages.HTTP_ERROR)


def api_error_response(exc: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.to_payload(),
    )


def http_exception_response(exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=normalize_http_exception(exc),
    )


def bad_request(code: str, message: str) -> ApiError:
    return ApiError(
        status_code=status.HTTP_400_BAD_REQUEST,
        code=code,
        message=message,
    )


def unauthorized(message: str = Messages.AUTHENTICATION_REQUIRED) -> ApiError:
    return ApiError(
        status_code=status.HTTP_401_UNAUTHORIZED,
        code="unauthorized",
        message=message,
    )


def forbidden(message: str = Messages.FORBIDDEN) -> ApiError:
    return ApiError(
        status_code=status.HTTP_403_FORBIDDEN,
        code="forbidden",
        message=message,
    )


def not_found(message: str) -> ApiError:
    return ApiError(
        status_code=status.HTTP_404_NOT_FOUND,
        code="not_found",
        message=message,
    )


def conflict(code: str, message: str) -> ApiError:
    return ApiError(
        status_code=status.HTTP_409_CONFLICT,
        code=code,
        message=message,
    )


def gone(code: str, message: str) -> ApiError:
    return ApiError(
        status_code=status.HTTP_410_GONE,
        code=code,
        message=message,
    )
