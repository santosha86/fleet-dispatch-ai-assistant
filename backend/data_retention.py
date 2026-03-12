"""Data Retention Policy — scheduled cleanup of audit logs and caches.

- Audit logs: entries older than AUDIT_LOG_RETENTION_DAYS are removed.
- Caches: expired entries in query/SQL/result caches are purged.
- Runs on a background thread at CACHE_CLEANUP_INTERVAL_HOURS intervals.
"""

import time
import threading
import logging
from datetime import datetime, timedelta
from pathlib import Path

logger = logging.getLogger(__name__)

# --- Configuration ---
AUDIT_LOG_RETENTION_DAYS = 30
CACHE_CLEANUP_INTERVAL_HOURS = 1

_AUDIT_LOG_PATH = Path(__file__).resolve().parent / "audit.log"

_scheduler_started = False


def cleanup_audit_logs() -> int:
    """Remove audit log entries older than AUDIT_LOG_RETENTION_DAYS.

    Returns:
        Number of entries deleted.
    """
    if not _AUDIT_LOG_PATH.exists():
        return 0

    cutoff = datetime.now() - timedelta(days=AUDIT_LOG_RETENTION_DAYS)
    kept_lines = []
    deleted_count = 0

    try:
        with open(_AUDIT_LOG_PATH, "r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                # Parse timestamp from audit log format: "2026-03-10 12:34:56,789 | ..."
                try:
                    timestamp_str = line.split(" | ", 1)[0].strip()
                    entry_time = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S,%f")
                    if entry_time >= cutoff:
                        kept_lines.append(line)
                    else:
                        deleted_count += 1
                except (ValueError, IndexError):
                    # Can't parse timestamp — keep the line
                    kept_lines.append(line)

        if deleted_count > 0:
            with open(_AUDIT_LOG_PATH, "w", encoding="utf-8") as f:
                f.write("\n".join(kept_lines))
                if kept_lines:
                    f.write("\n")
            logger.info("Audit log cleanup: removed %d entries older than %d days",
                        deleted_count, AUDIT_LOG_RETENTION_DAYS)
    except Exception as e:
        logger.error("Audit log cleanup failed: %s", e)

    return deleted_count


def cleanup_caches() -> int:
    """Clear expired entries from all in-memory caches.

    Returns:
        Total number of entries cleared.
    """
    cleared = 0

    # 1. Result cache in main.py
    try:
        from .main import _result_cache, _cache_lock, _CACHE_TTL_SECONDS
        now = time.time()
        with _cache_lock:
            expired = [k for k, v in _result_cache.items()
                       if now - v["created_at"] > _CACHE_TTL_SECONDS]
            for k in expired:
                del _result_cache[k]
            cleared += len(expired)
    except Exception:
        pass

    # 2. Query cache and SQL cache in sql_agent
    try:
        from .agents.sql_agent import (
            _query_cache, _query_cache_lock, _QUERY_CACHE_TTL,
            _sql_cache, _sql_cache_lock, _SQL_CACHE_TTL,
        )
        now = time.time()
        with _query_cache_lock:
            expired = [k for k, v in _query_cache.items()
                       if now - v["timestamp"] > _QUERY_CACHE_TTL]
            for k in expired:
                del _query_cache[k]
            cleared += len(expired)

        with _sql_cache_lock:
            expired = [k for k, v in _sql_cache.items()
                       if now - v["timestamp"] > _SQL_CACHE_TTL]
            for k in expired:
                del _sql_cache[k]
            cleared += len(expired)
    except Exception:
        pass

    if cleared > 0:
        logger.info("Cache cleanup: cleared %d expired entries", cleared)

    return cleared


def _retention_loop():
    """Background loop that runs cleanup tasks on schedule."""
    interval = CACHE_CLEANUP_INTERVAL_HOURS * 3600
    while True:
        time.sleep(interval)
        try:
            cleanup_audit_logs()
            cleanup_caches()
        except Exception as e:
            logger.error("Retention scheduler error: %s", e)


def start_retention_scheduler():
    """Start the background retention scheduler thread (once)."""
    global _scheduler_started
    if _scheduler_started:
        return
    _scheduler_started = True
    t = threading.Thread(target=_retention_loop, daemon=True, name="data-retention")
    t.start()
    logger.info("Data retention scheduler started (audit=%dd, cache interval=%dh)",
                AUDIT_LOG_RETENTION_DAYS, CACHE_CLEANUP_INTERVAL_HOURS)
