"""JWT Authentication module for Fleet Dispatch API."""

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
        }
    with open(_USERS_FILE, "w") as f:
        json.dump(users, f, indent=2)
    return users


def load_users() -> dict:
    """Load users from users.json. Auto-create from defaults if missing."""
    if not _USERS_FILE.exists():
        return _generate_users_file()
    with open(_USERS_FILE) as f:
        return json.load(f)


def create_access_token(username: str, expires_delta: timedelta = None) -> str:
    """Create a JWT access token."""
    if expires_delta is None:
        expires_delta = timedelta(hours=TOKEN_EXPIRY_HOURS)
    now = time.time()
    payload = {
        "sub": username,
        "iat": now,
        "exp": now + expires_delta.total_seconds(),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


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
