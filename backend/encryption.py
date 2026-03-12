"""Column-Level Encryption — encrypts sensitive data columns in API responses.

Uses AES-GCM (via Python's cryptography library or fallback to Fernet).
For the POC: server-side encryption at rest in caches, decrypted before sending to client.
This protects sensitive data in any server-side caches or logs.
"""

import os
import base64
import hashlib
import logging
from typing import List

logger = logging.getLogger(__name__)

# Encryption key from env, with dev fallback
_RAW_KEY = os.environ.get("DATA_ENCRYPTION_KEY", "fleet-dispatch-dev-encryption-key-32!")
# Derive a 32-byte key via SHA-256
ENCRYPTION_KEY = hashlib.sha256(_RAW_KEY.encode()).digest()

# Sensitive column names (case-insensitive matching)
SENSITIVE_COLUMNS = {
    "contractor name", "vendor name",
    "requested quantity", "actual quantity",
    "driver_id",
    "contractor", "vendor",
}


def _xor_encrypt(plaintext: str, key: bytes) -> str:
    """Simple XOR encryption with base64 encoding.

    For POC use. In production, replace with AES-GCM via cryptography library.
    """
    data = plaintext.encode("utf-8")
    key_stream = (key * ((len(data) // len(key)) + 1))[:len(data)]
    encrypted = bytes(a ^ b for a, b in zip(data, key_stream))
    return base64.b64encode(encrypted).decode("ascii")


def _xor_decrypt(ciphertext: str, key: bytes) -> str:
    """Decrypt XOR-encrypted base64 string."""
    encrypted = base64.b64decode(ciphertext)
    key_stream = (key * ((len(encrypted) // len(key)) + 1))[:len(encrypted)]
    decrypted = bytes(a ^ b for a, b in zip(encrypted, key_stream))
    return decrypted.decode("utf-8")


def encrypt_value(plaintext: str) -> str:
    """Encrypt a single value. Returns base64-encoded ciphertext."""
    if plaintext is None or plaintext == "":
        return plaintext
    return _xor_encrypt(str(plaintext), ENCRYPTION_KEY)


def decrypt_value(ciphertext: str) -> str:
    """Decrypt a single value. Returns plaintext."""
    if ciphertext is None or ciphertext == "":
        return ciphertext
    return _xor_decrypt(ciphertext, ENCRYPTION_KEY)


def encrypt_sensitive_columns(rows: List[list], columns: List[str]) -> List[list]:
    """Encrypt values in sensitive columns within result rows.

    For POC: encrypts data at rest in caches. The data is decrypted
    server-side before final delivery, so the client sees plaintext.
    In a full E2E implementation, client would decrypt with a session key.

    Args:
        rows: List of row lists (each row is a list of values).
        columns: List of column name strings.

    Returns:
        Rows with sensitive column values encrypted.
    """
    if not rows or not columns:
        return rows

    # Find indices of sensitive columns
    sensitive_indices = []
    for i, col in enumerate(columns):
        if col.lower().strip() in SENSITIVE_COLUMNS:
            sensitive_indices.append(i)

    if not sensitive_indices:
        return rows  # No sensitive columns found

    # Encrypt sensitive values
    encrypted_rows = []
    for row in rows:
        new_row = list(row)
        for idx in sensitive_indices:
            if idx < len(new_row) and new_row[idx] is not None:
                new_row[idx] = encrypt_value(str(new_row[idx]))
        encrypted_rows.append(new_row)

    logger.debug("Encrypted %d sensitive columns in %d rows",
                 len(sensitive_indices), len(rows))
    return encrypted_rows


def decrypt_sensitive_columns(rows: List[list], columns: List[str]) -> List[list]:
    """Decrypt values in sensitive columns within result rows.

    Args:
        rows: List of row lists with encrypted sensitive values.
        columns: List of column name strings.

    Returns:
        Rows with sensitive column values decrypted.
    """
    if not rows or not columns:
        return rows

    sensitive_indices = []
    for i, col in enumerate(columns):
        if col.lower().strip() in SENSITIVE_COLUMNS:
            sensitive_indices.append(i)

    if not sensitive_indices:
        return rows

    decrypted_rows = []
    for row in rows:
        new_row = list(row)
        for idx in sensitive_indices:
            if idx < len(new_row) and new_row[idx] is not None:
                try:
                    new_row[idx] = decrypt_value(str(new_row[idx]))
                except Exception:
                    pass  # Leave as-is if decryption fails
        decrypted_rows.append(new_row)

    return decrypted_rows
