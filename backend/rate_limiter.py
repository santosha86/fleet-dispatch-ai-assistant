"""In-memory per-user rate limiter."""

import time
from collections import defaultdict
from fastapi import HTTPException


class RateLimiter:
    def __init__(self, max_requests: int = 60, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, list[float]] = defaultdict(list)

    def check(self, user_key: str):
        """Raise HTTPException(429) if rate limit exceeded."""
        now = time.time()
        window_start = now - self.window_seconds
        self._requests[user_key] = [
            t for t in self._requests[user_key] if t > window_start
        ]
        if len(self._requests[user_key]) >= self.max_requests:
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded. Please wait before making more requests.",
            )
        self._requests[user_key].append(now)


rate_limiter = RateLimiter(max_requests=60, window_seconds=60)
