"""MFA (TOTP) module — Time-based One-Time Password support.

Uses pyotp for TOTP generation/verification and qrcode for QR code generation.
Compatible with Google Authenticator, Microsoft Authenticator, Authy, etc.
"""

import base64
import io

import pyotp
import qrcode


APP_NAME = "Fleet Dispatch"


def generate_totp_secret() -> str:
    """Generate a random base32 TOTP secret."""
    return pyotp.random_base32()


def get_totp_uri(username: str, secret: str) -> str:
    """Generate an otpauth:// URI for QR code scanning.

    Args:
        username: The user's display name in the authenticator app.
        secret: The base32 TOTP secret.

    Returns:
        otpauth:// URI string.
    """
    totp = pyotp.TOTP(secret)
    return totp.provisioning_uri(name=username, issuer_name=APP_NAME)


def verify_totp(secret: str, code: str) -> bool:
    """Verify a 6-digit TOTP code against the secret.

    Allows a 1-step tolerance (±30 seconds) to handle clock skew.

    Args:
        secret: The base32 TOTP secret.
        code: The 6-digit code from the authenticator app.

    Returns:
        True if the code is valid.
    """
    totp = pyotp.TOTP(secret)
    return totp.verify(code, valid_window=1)


def generate_qr_code(uri: str) -> str:
    """Generate a QR code PNG image as a base64-encoded string.

    Args:
        uri: The otpauth:// URI to encode.

    Returns:
        Base64-encoded PNG image string (prefix with "data:image/png;base64," for display).
    """
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(uri)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    buffer.seek(0)
    b64 = base64.b64encode(buffer.read()).decode("utf-8")
    return f"data:image/png;base64,{b64}"
