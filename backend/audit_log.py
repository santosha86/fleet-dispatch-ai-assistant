"""Audit logging middleware — logs every request with username, path, status, duration."""

import time
import logging
from pathlib import Path

import jwt
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

_log_file = Path(__file__).resolve().parent / "audit.log"

audit_logger = logging.getLogger("audit")
audit_logger.setLevel(logging.INFO)
audit_logger.propagate = False

_handler = logging.FileHandler(str(_log_file), encoding="utf-8")
_handler.setFormatter(logging.Formatter("%(asctime)s | %(message)s"))
audit_logger.addHandler(_handler)


class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.time()
        response = await call_next(request)
        duration_ms = (time.time() - start) * 1000

        # Extract username from JWT (best effort, no verification)
        username = "anonymous"
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            try:
                payload = jwt.decode(
                    auth_header[7:], options={"verify_signature": False}
                )
                username = payload.get("sub", "anonymous")
            except Exception:
                pass

        audit_logger.info(
            "user=%s | %s %s | status=%s | duration=%.0fms",
            username,
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        return response
