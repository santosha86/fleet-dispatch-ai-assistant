"""JWT Authentication module for Fleet Dispatch API.

Supports access tokens (8h), refresh tokens (7d), and MFA-pending tokens (5min).
"""

import os
import json
import time
import hashlib
import secrets
from pathlib import Path
from datetime import timedelta

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

# --- Configuration ---
SECRET_KEY = os.environ.get(
    "JWT_SECRET", "fleet-dispatch-poc-secret-change-in-production"
)
ALGORITHM = "HS256"
TOKEN_EXPIRY_HOURS = 8
REFRESH_TOKEN_EXPIRY_DAYS = 7

# --- OAuth2 scheme ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/login")

# --- Users file ---
_USERS_FILE = Path(__file__).resolve().parent / "users.json"

# Default users (used to auto-generate users.json on first run)
_DEFAULT_USERS = {
    "pb": "admin1234",
    "user1": "user1pass",
    "user2": "user2pass",
    "user3": "user3pass",
    "user4": "user4pass",
}


def _hash_password(password: str) -> str:
    """Hash password using PBKDF2-SHA256 (Python built-in, no external deps)."""
    salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000)
    return f"{salt}${hashed.hex()}"


def _verify_password(plain_password: str, stored_hash: str) -> bool:
    """Verify password against PBKDF2-SHA256 hash."""
    try:
        salt, hash_hex = stored_hash.split("$", 1)
        expected = hashlib.pbkdf2_hmac(
            "sha256", plain_password.encode(), salt.encode(), 100_000
        )
        return secrets.compare_digest(expected.hex(), hash_hex)
    except (ValueError, AttributeError):
        return False


def _generate_users_file():
    """Generate users.json with hashed passwords from defaults."""
    users = {}
    for username, password in _DEFAULT_USERS.items():
        users[username] = {
            "password_hash": _hash_password(password),
            "role": "admin" if username == "pb" else "user",
            "active": True,
            "mfa_secret": None,
            "mfa_enabled": False,
        }
    with open(_USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)
    return users


def save_users(users: dict):
    """Save users dict to users.json."""
    with open(_USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)


def load_users() -> dict:
    """Load users from users.json. Auto-create from defaults if missing."""
    if not _USERS_FILE.exists():
        return _generate_users_file()
    with open(_USERS_FILE) as f:
        return json.load(f)


def create_access_token(username: str, role: str = "user", expires_delta: timedelta = None) -> str:
    """Create a JWT access token with role claim."""
    if expires_delta is None:
        expires_delta = timedelta(hours=TOKEN_EXPIRY_HOURS)
    now = time.time()
    payload = {
        "sub": username,
        "role": role,
        "type": "access",
        "iat": now,
        "exp": now + expires_delta.total_seconds(),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(username: str) -> str:
    """Create a JWT refresh token (7-day expiry)."""
    now = time.time()
    payload = {
        "sub": username,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=REFRESH_TOKEN_EXPIRY_DAYS).total_seconds(),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_refresh_token(token: str) -> str:
    """Validate a refresh token and return the username.

    Raises HTTPException on invalid/expired token.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type — expected refresh token.",
            )
        username = payload.get("sub")
        if not username:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token.",
            )
        # Verify user still exists and is active
        users = load_users()
        user = users.get(username)
        if not user or not user.get("active", True):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is inactive.",
            )
        return username
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has expired. Please login again.",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
        )


def create_mfa_pending_token(username: str) -> str:
    """Create a short-lived JWT for MFA verification (5 minutes)."""
    now = time.time()
    payload = {
        "sub": username,
        "type": "mfa_pending",
        "iat": now,
        "exp": now + 300,  # 5 minutes
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_mfa_pending_token(token: str) -> str:
    """Validate an MFA-pending token and return the username."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "mfa_pending":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type — expected MFA pending token.",
            )
        username = payload.get("sub")
        if not username:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid MFA token.",
            )
        return username
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="MFA token has expired. Please login again.",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MFA token.",
        )


def authenticate_user(username: str, password: str):
    """Validate username/password. Returns username if valid, None otherwise."""
    username = username.strip().lower()
    users = load_users()
    user = users.get(username)
    if not user:
        return None
    if not user.get("active", True):
        return None
    if not _verify_password(password, user["password_hash"]):
        return None
    return username


async def get_current_user(token: str = Depends(oauth2_scheme)) -> str:
    """FastAPI dependency — extract and validate JWT Bearer token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        # Only accept access tokens (not refresh or mfa_pending)
        token_type = payload.get("type", "access")
        if token_type != "access":
            raise credentials_exception
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please login again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        raise credentials_exception

    # Verify user still exists and is active
    users = load_users()
    user = users.get(username)
    if not user or not user.get("active", True):
        raise credentials_exception

    return username
