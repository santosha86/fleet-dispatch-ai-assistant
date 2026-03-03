"""
E2E tests for server-side pagination of large query results.

Tests:
1. POST /api/query with page_size -> returns page 1 + result_id
2. GET /api/table-data/{result_id}?page=N -> returns subsequent pages
3. POST /api/query/stream with page_size -> same pagination in SSE
4. Edge cases: small results, invalid pages, expired cache

Uses fixed queries from FIXED_QUERIES to avoid LLM latency.
"""

import sys
import json
import requests
import time

BASE_URL = "http://localhost:8000"
SESSION_ID = "e2e-pagination-test"

# These are exact keys from FIXED_QUERIES that bypass the LLM for SQL
# "Which waybills are assigned to VENDOR-A?" -> SELECT * with many rows
LARGE_QUERY = "Which waybills are assigned to VENDOR-A?"
# "How many waybills are Delivered / Expired / Cancelled?" -> 1 row, 3 cols
SMALL_QUERY = "How many waybills are Delivered / Expired / Cancelled?"

passed = 0
failed = 0
skipped = 0


def run_test(name, fn):
    global passed, failed
    print(f"--- {name} ---")
    try:
        fn()
        passed += 1
    except AssertionError as e:
        print(f"  [FAIL] {e}")
        failed += 1
    except Exception as e:
        print(f"  [ERROR] {e}")
        failed += 1
    print()


# Store across tests
shared = {}


def test_1_pagination_triggered():
    """Large query with small page_size returns page 1 + result_id."""
    r = requests.post(f"{BASE_URL}/api/query",
        json={
            "query": LARGE_QUERY,
            "session_id": SESSION_ID,
            "route": "sql",
            "page_size": 5,
        },
        timeout=300)

    assert r.status_code == 200, f"Status {r.status_code}: {r.text[:200]}"
    data = r.json()
    table = data.get("table_data")
    assert table is not None, "No table_data in response"

    rows = table["rows"]
    total = table.get("total_row_count")
    result_id = table.get("result_id")
    page = table.get("page")
    total_pages = table.get("total_pages")
    page_size = table.get("page_size")

    print(f"  Rows on page 1: {len(rows)}")
    print(f"  Total rows: {total}")
    print(f"  result_id: {result_id}")
    print(f"  Page: {page}/{total_pages}, page_size={page_size}")

    assert total is not None and total > 5, \
        f"Expected total > 5 for vendor query, got {total}"
    assert len(rows) == 5, f"Expected 5 rows, got {len(rows)}"
    assert result_id is not None, "Missing result_id"
    assert page == 1, f"Expected page=1, got {page}"
    assert total_pages > 1, f"Expected total_pages > 1, got {total_pages}"
    assert page_size == 5, f"Expected page_size=5, got {page_size}"

    shared["result_id"] = result_id
    shared["total_rows"] = total
    shared["total_pages"] = total_pages
    shared["columns"] = table["columns"]

    print(f"  [PASS] Pagination active: {len(rows)} of {total} rows, {total_pages} pages")


def test_2_fetch_page_2():
    """GET /api/table-data/{result_id}?page=2 returns correct data."""
    result_id = shared.get("result_id")
    assert result_id, "No result_id from Test 1"

    r = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
        params={"page": 2, "page_size": 5},
        timeout=10)

    assert r.status_code == 200, f"Status {r.status_code}: {r.text[:200]}"
    data = r.json()

    rows = data["rows"]
    page = data["page"]
    total_pages = data["total_pages"]
    total = data["total_row_count"]

    assert page == 2, f"Expected page=2, got {page}"
    assert len(rows) > 0, "Page 2 should have rows"
    assert len(rows) <= 5, f"Expected <= 5 rows, got {len(rows)}"
    assert total_pages == shared["total_pages"], "total_pages mismatch"
    assert total == shared["total_rows"], "total_row_count mismatch"
    assert data["columns"] == shared["columns"], "Columns mismatch"

    print(f"  [PASS] Page 2: {len(rows)} rows, page={page}/{total_pages}")


def test_3_fetch_all_pages():
    """Iterate all pages, verify combined rows == total_row_count."""
    result_id = shared.get("result_id")
    total_rows = shared.get("total_rows", 0)
    total_pages = shared.get("total_pages", 0)
    assert result_id, "No result_id from Test 1"

    all_rows = []
    for p in range(1, total_pages + 1):
        r = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
            params={"page": p, "page_size": 5},
            timeout=10)
        assert r.status_code == 200, f"Page {p}: status {r.status_code}"
        data = r.json()
        assert data["page"] == p, f"Expected page={p}, got {data['page']}"
        all_rows.extend(data["rows"])

    assert len(all_rows) == total_rows, \
        f"Combined rows ({len(all_rows)}) != total ({total_rows})"

    print(f"  [PASS] All {total_pages} pages: {len(all_rows)} rows == {total_rows} total")


def test_4_small_query_no_pagination():
    """Small result should NOT have pagination metadata."""
    r = requests.post(f"{BASE_URL}/api/query",
        json={
            "query": SMALL_QUERY,
            "session_id": SESSION_ID + "-small",
            "route": "sql",
            "page_size": 100,
        },
        timeout=300)

    assert r.status_code == 200, f"Status {r.status_code}"
    data = r.json()
    table = data.get("table_data")

    if table is None:
        print("  [PASS] No table_data (text-only response)")
        return

    rows = table.get("rows", [])
    result_id = table.get("result_id")

    assert result_id is None, f"Small result should not have result_id, got {result_id}"
    assert table.get("page") is None, "Small result should not have page"
    assert table.get("total_pages") is None, "Small result should not have total_pages"

    print(f"  [PASS] Small query ({len(rows)} rows): no pagination metadata")


def test_5_invalid_page_zero():
    """page=0 should return 400."""
    result_id = shared.get("result_id")
    assert result_id, "No result_id"

    r = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
        params={"page": 0, "page_size": 5},
        timeout=10)

    assert r.status_code == 400, f"Expected 400 for page=0, got {r.status_code}"
    print(f"  [PASS] page=0 -> 400: {r.json().get('detail')}")


def test_6_nonexistent_result_id():
    """Random result_id should return 404."""
    r = requests.get(f"{BASE_URL}/api/table-data/nonexistent-fake-uuid",
        params={"page": 1, "page_size": 5},
        timeout=10)

    assert r.status_code == 404, f"Expected 404, got {r.status_code}"
    print(f"  [PASS] Fake result_id -> 404: {r.json().get('detail')}")


def test_7_stream_pagination():
    """POST /api/query/stream with page_size should paginate."""
    r = requests.post(f"{BASE_URL}/api/query/stream",
        json={
            "query": LARGE_QUERY,
            "session_id": SESSION_ID + "-stream",
            "route": "sql",
            "page_size": 5,
        },
        timeout=300,
        stream=True)

    assert r.status_code == 200, f"Status {r.status_code}"

    # Parse last SSE data line
    last_data = ""
    for line in r.iter_lines(decode_unicode=True):
        if line and line.startswith("data: "):
            last_data = line[6:]

    assert last_data, "No SSE data received"
    data = json.loads(last_data)
    table = data.get("table_data")
    assert table is not None, "No table_data in stream response"

    rows = table.get("rows", [])
    result_id = table.get("result_id")
    total = table.get("total_row_count")
    page = table.get("page")

    assert total > 5, f"Expected > 5 total, got {total}"
    assert len(rows) == 5, f"Expected 5 rows, got {len(rows)}"
    assert result_id is not None, "Missing result_id in stream"
    assert page == 1, f"Expected page=1, got {page}"

    print(f"  [PASS] Stream pagination: {len(rows)} of {total} rows, result_id={result_id[:12]}...")


def test_8_default_page_size():
    """No page_size -> default 100."""
    r = requests.post(f"{BASE_URL}/api/query",
        json={
            "query": LARGE_QUERY,
            "session_id": SESSION_ID + "-default",
            "route": "sql",
            # no page_size
        },
        timeout=300)

    assert r.status_code == 200
    data = r.json()
    table = data.get("table_data")
    assert table is not None

    rows = table["rows"]
    total = table.get("total_row_count")
    page_size = table.get("page_size")

    if total is not None and total > 100:
        assert len(rows) == 100, f"Expected 100 rows (default), got {len(rows)}"
        assert page_size == 100, f"Expected page_size=100, got {page_size}"
        print(f"  [PASS] Default page_size=100: {len(rows)} of {total} rows")
    else:
        print(f"  [PASS] Total ({total}) <= 100, all rows returned: {len(rows)}")


def test_9_page_beyond_total():
    """Page beyond total_pages returns empty rows."""
    result_id = shared.get("result_id")
    total_pages = shared.get("total_pages", 0)
    assert result_id, "No result_id"

    beyond = total_pages + 10
    r = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
        params={"page": beyond, "page_size": 5},
        timeout=10)

    assert r.status_code == 200, f"Expected 200, got {r.status_code}"
    rows = r.json()["rows"]
    assert len(rows) == 0, f"Expected 0 rows for page {beyond}, got {len(rows)}"

    print(f"  [PASS] Page {beyond} (beyond {total_pages}) -> 0 rows")


def test_10_pagination_consistent_across_requests():
    """Same result_id returns same data on repeated requests."""
    result_id = shared.get("result_id")
    assert result_id, "No result_id"

    r1 = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
        params={"page": 1, "page_size": 5}, timeout=10)
    r2 = requests.get(f"{BASE_URL}/api/table-data/{result_id}",
        params={"page": 1, "page_size": 5}, timeout=10)

    assert r1.status_code == 200 and r2.status_code == 200
    assert r1.json()["rows"] == r2.json()["rows"], "Same page returns different data"

    print("  [PASS] Same result_id + page returns consistent data")


def main():
    print("=" * 60)
    print("E2E Tests: Server-Side Pagination")
    print(f"Backend: {BASE_URL}")
    print("=" * 60)
    print()

    tests = [
        ("Test 1: Large query triggers pagination", test_1_pagination_triggered),
        ("Test 2: Fetch page 2 via GET endpoint", test_2_fetch_page_2),
        ("Test 3: Fetch all pages, verify total", test_3_fetch_all_pages),
        ("Test 4: Small query - no pagination", test_4_small_query_no_pagination),
        ("Test 5: Invalid page=0 -> 400", test_5_invalid_page_zero),
        ("Test 6: Non-existent result_id -> 404", test_6_nonexistent_result_id),
        ("Test 7: Streaming endpoint pagination", test_7_stream_pagination),
        ("Test 8: Default page_size = 100", test_8_default_page_size),
        ("Test 9: Page beyond total -> empty", test_9_page_beyond_total),
        ("Test 10: Consistent across requests", test_10_pagination_consistent_across_requests),
    ]

    for name, fn in tests:
        run_test(name, fn)

    print("=" * 60)
    total = passed + failed
    print(f"Results: {passed}/{total} passed, {failed} failed")
    if failed == 0:
        print("ALL PAGINATION E2E TESTS PASSED")
    else:
        print(f"FAILURES: {failed}")
    print("=" * 60)

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
