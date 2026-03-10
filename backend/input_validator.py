"""Input validation for user queries — length limit and SQL injection detection."""

import re
from fastapi import HTTPException

MAX_QUERY_LENGTH = 500

_SQL_INJECTION_PATTERNS = [
    r";\s*(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|TRUNCATE)\b",
    r"'\s*(OR|AND)\s+'?\d*'?\s*=\s*'?\d*'?",
    r"UNION\s+(ALL\s+)?SELECT",
    r"--\s*$",
    r"/\*.*\*/",
    r"\bEXEC(UTE)?\b",
    r"\bxp_\w+",
]

_compiled = [re.compile(p, re.IGNORECASE) for p in _SQL_INJECTION_PATTERNS]


def validate_query(query: str) -> str:
    """Validate and return cleaned query, or raise HTTPException."""
    if not query or not query.strip():
        raise HTTPException(status_code=400, detail="Query cannot be empty")

    query = query.strip()

    if len(query) > MAX_QUERY_LENGTH:
        raise HTTPException(
            status_code=400,
            detail=f"Query too long. Maximum {MAX_QUERY_LENGTH} characters.",
        )

    for pattern in _compiled:
        if pattern.search(query):
            raise HTTPException(
                status_code=400,
                detail="Query contains disallowed patterns.",
            )

    return query
