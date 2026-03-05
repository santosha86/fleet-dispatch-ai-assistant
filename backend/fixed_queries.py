import re as _re

# Fixed SQL queries for category questions
Fuel_Type_Desc_quantity = """
SELECT
  "Fuel Type Desc",
  SUM("Requested Quantity") AS total_requested_quantity
FROM waybills
GROUP BY "Fuel Type Desc"
ORDER BY total_requested_quantity DESC
LIMIT 1;
"""

status_of_waybill = """
SELECT
  SUM(CASE WHEN "Waybill Status Desc" = 'Delivered' THEN 1 ELSE 0 END) AS delivered_count,
  SUM(CASE WHEN "Waybill Status Desc" = 'Expired' THEN 1 ELSE 0 END) AS expired_count,
  SUM(CASE WHEN "Waybill Status Desc" = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count
FROM waybills;
"""

details_of_waybill = """
SELECT
  "Waybill Number",
  "Waybill Status Desc",
  "Waybill Status Date",
  "Waybill Status Time"
FROM waybills
WHERE "Waybill Number" = 'D6-25-0039536';
"""

waybills_for_contractor = """
SELECT *
FROM waybills
WHERE LOWER("Vendor Name") LIKE '%alhbbas%'
   OR LOWER("Vendor Name") LIKE '%trading%'
   OR LOWER("Vendor Name") LIKE '%transport%';
"""

contractor_wise_waybills = """
SELECT "Vendor Name", "Waybill Number"
FROM waybills
ORDER BY "VENDOR-A";
"""

full_details = """
SELECT *
FROM waybills
WHERE "Waybill Number" = '1-25-0010844';
"""

vendor_rejected_requests = """
SELECT
  "Vendor Name",
  COUNT(*) AS rejected_count
FROM waybills
WHERE "Waybill Status Desc" = 'Rejected'
GROUP BY "Vendor Name"
ORDER BY rejected_count DESC
LIMIT 1;
"""

vendors_requests = """
SELECT
  "Vendor Name",
  COUNT(*) AS total_requests
FROM waybills
GROUP BY "Vendor Name"
ORDER BY total_requests DESC;
"""

# --- Common pattern queries (instant, no LLM needed) ---

waybill_count_by_month = """
SELECT
  strftime('%Y-%m', "Scheduled Date") AS month,
  COUNT(*) AS waybill_count
FROM waybills
GROUP BY month
ORDER BY month;
"""

contractor_waybill_count = """
SELECT
  "Vendor Name",
  COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Vendor Name"
ORDER BY waybill_count DESC;
"""

cancelled_vs_rejected_by_contractor = """
SELECT
  "Vendor Name",
  SUM(CASE WHEN "Waybill Status Desc" = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count,
  SUM(CASE WHEN "Waybill Status Desc" = 'Rejected' THEN 1 ELSE 0 END) AS rejected_count
FROM waybills
GROUP BY "Vendor Name"
ORDER BY "Vendor Name";
"""

monthly_cancelled_vs_expired = """
SELECT
  strftime('%Y-%m', "Waybill Status Date") AS month,
  SUM(CASE WHEN "Waybill Status Desc" = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(CASE WHEN "Waybill Status Desc" = 'Expired' THEN 1 ELSE 0 END) AS expired
FROM waybills
WHERE "Waybill Status Desc" IN ('Cancelled', 'Expired')
GROUP BY month
ORDER BY month;
"""

total_waybills_count = """
SELECT COUNT(*) AS total_waybills FROM waybills;
"""

waybill_status_summary = """
SELECT
  "Waybill Status Desc",
  COUNT(*) AS count
FROM waybills
GROUP BY "Waybill Status Desc"
ORDER BY count DESC;
"""

top_plants_by_waybills = """
SELECT
  "Power Plant Desc",
  COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Power Plant Desc"
ORDER BY waybill_count DESC;
"""

waybill_count_by_fuel_type = """
SELECT
  "Fuel Type Desc",
  COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Fuel Type Desc"
ORDER BY waybill_count DESC;
"""

# --- Additional common SQL queries (used by fuzzy patterns below) ---

delivered_count = """
SELECT COUNT(*) AS delivered_count FROM waybills WHERE "Waybill Status Desc" = 'Delivered';
"""

cancelled_count = """
SELECT COUNT(*) AS cancelled_count FROM waybills WHERE "Waybill Status Desc" = 'Cancelled';
"""

expired_count = """
SELECT COUNT(*) AS expired_count FROM waybills WHERE "Waybill Status Desc" = 'Expired';
"""

rejected_count = """
SELECT COUNT(*) AS rejected_count FROM waybills WHERE "Waybill Status Desc" = 'Rejected';
"""

top_vendors_by_waybills = """
SELECT "Vendor Name", COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Vendor Name"
ORDER BY waybill_count DESC
LIMIT 10;
"""

top_routes_by_waybills = """
SELECT "Route Desc", COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Route Desc"
ORDER BY waybill_count DESC
LIMIT 10;
"""

recent_waybills = """
SELECT "Waybill Number", "Waybill Status Desc", "Scheduled Date", "Vendor Name", "Power Plant Desc"
FROM waybills
ORDER BY "Scheduled Date" DESC
LIMIT 20;
"""

total_requested_quantity = """
SELECT SUM("Requested Quantity") AS total_requested_quantity FROM waybills;
"""

total_actual_quantity = """
SELECT SUM("Actual Quantity") AS total_actual_quantity FROM waybills;
"""

avg_requested_quantity = """
SELECT ROUND(AVG("Requested Quantity"), 2) AS avg_requested_quantity FROM waybills;
"""

waybill_count_by_route = """
SELECT "Route Desc", COUNT(*) AS waybill_count
FROM waybills
GROUP BY "Route Desc"
ORDER BY waybill_count DESC;
"""

vendors_with_most_cancelled = """
SELECT "Vendor Name", COUNT(*) AS cancelled_count
FROM waybills
WHERE "Waybill Status Desc" = 'Cancelled'
GROUP BY "Vendor Name"
ORDER BY cancelled_count DESC
LIMIT 10;
"""

vendors_with_most_expired = """
SELECT "Vendor Name", COUNT(*) AS expired_count
FROM waybills
WHERE "Waybill Status Desc" = 'Expired'
GROUP BY "Vendor Name"
ORDER BY expired_count DESC
LIMIT 10;
"""

plants_by_quantity = """
SELECT "Power Plant Desc", SUM("Requested Quantity") AS total_quantity
FROM waybills
GROUP BY "Power Plant Desc"
ORDER BY total_quantity DESC;
"""

# Mapping: question text -> SQL query
FIXED_QUERIES = {
    # Original fixed queries
    "How many waybills are Delivered / Expired / Cancelled?": status_of_waybill,
    "Which fuel type has the highest total requested quantity?": Fuel_Type_Desc_quantity,
    "What is the current status of waybill D6-25-0039536?": details_of_waybill,
    "Show full details of waybill 1-25-0010844": full_details,
    "Which waybills are assigned to VENDOR-A?": waybills_for_contractor,
    "Show contractor-wise waybill list": contractor_wise_waybills,
    "Which vendor has the highest number of rejected requests": vendor_rejected_requests,
    "Which vendors created the most requests": vendors_requests,
}

# --- Fuzzy fixed query matching ---
# Maps normalized patterns to SQL queries for common questions
# These match loosely so users don't need exact phrasing

_PATTERN_QUERIES = [
    # Monthly patterns
    (["waybill", "count", "month"], waybill_count_by_month),
    (["waybill", "month"], waybill_count_by_month),
    (["monthly", "waybill"], waybill_count_by_month),
    (["show", "waybill", "by", "month"], waybill_count_by_month),

    # Contractor/vendor count patterns
    (["how", "many", "waybill", "each", "contractor"], contractor_waybill_count),
    (["how", "many", "waybill", "per", "contractor"], contractor_waybill_count),
    (["how", "many", "waybill", "each", "vendor"], contractor_waybill_count),
    (["waybill", "count", "contractor"], contractor_waybill_count),
    (["waybill", "count", "vendor"], contractor_waybill_count),
    (["contractor", "waybill", "count"], contractor_waybill_count),

    # Cancelled vs rejected (more specific patterns first to beat contractor count)
    (["contractor", "cancelled", "rejected", "waybill"], cancelled_vs_rejected_by_contractor),
    (["contractor", "cancelled", "rejected", "count"], cancelled_vs_rejected_by_contractor),
    (["vendor", "cancelled", "rejected", "waybill"], cancelled_vs_rejected_by_contractor),
    (["contractor", "cancelled", "rejected"], cancelled_vs_rejected_by_contractor),
    (["vendor", "cancelled", "rejected"], cancelled_vs_rejected_by_contractor),
    (["cancelled", "vs", "rejected"], cancelled_vs_rejected_by_contractor),

    # Monthly cancelled vs expired
    (["monthly", "cancelled", "expired"], monthly_cancelled_vs_expired),
    (["month", "cancelled", "expired"], monthly_cancelled_vs_expired),
    (["trend", "cancelled", "expired"], monthly_cancelled_vs_expired),

    # Total count
    (["total", "waybill"], total_waybills_count),
    (["how", "many", "waybill"], total_waybills_count),
    (["count", "all", "waybill"], total_waybills_count),

    # Status summary
    (["waybill", "status", "summary"], waybill_status_summary),
    (["waybill", "by", "status"], waybill_status_summary),
    (["status", "breakdown"], waybill_status_summary),

    # Plants
    (["waybill", "by", "plant"], top_plants_by_waybills),
    (["top", "plant"], top_plants_by_waybills),
    (["plant", "waybill", "count"], top_plants_by_waybills),

    # Fuel type
    (["waybill", "by", "fuel"], waybill_count_by_fuel_type),
    (["fuel", "type", "count"], waybill_count_by_fuel_type),
    (["fuel", "type", "breakdown"], waybill_count_by_fuel_type),

    # Short/common queries (users type just entity names)
    (["contractor", "name"], contractor_waybill_count),
    (["vendor", "name"], contractor_waybill_count),
    (["plant", "name"], top_plants_by_waybills),
    (["power", "plant"], top_plants_by_waybills),
    (["fuel", "type"], waybill_count_by_fuel_type),

    # --- Delivered / Cancelled / Expired counts ---
    (["how", "many", "delivered"], delivered_count),
    (["count", "delivered"], delivered_count),
    (["delivered", "waybill"], delivered_count),
    (["how", "many", "cancelled"], cancelled_count),
    (["how", "many", "canceled"], cancelled_count),
    (["count", "cancelled"], cancelled_count),
    (["cancelled", "waybill"], cancelled_count),
    (["how", "many", "expired"], expired_count),
    (["count", "expired"], expired_count),
    (["expired", "waybill"], expired_count),
    (["how", "many", "rejected"], rejected_count),
    (["count", "rejected"], rejected_count),
    (["rejected", "waybill"], rejected_count),

    # --- Vendor/contractor rankings ---
    (["top", "vendor"], top_vendors_by_waybills),
    (["top", "contractor"], top_vendors_by_waybills),
    (["vendor", "ranking"], top_vendors_by_waybills),
    (["contractor", "ranking"], top_vendors_by_waybills),
    (["most", "vendor"], top_vendors_by_waybills),
    (["most", "contractor"], top_vendors_by_waybills),
    (["vendor", "most", "cancelled"], vendors_with_most_cancelled),
    (["contractor", "most", "cancelled"], vendors_with_most_cancelled),
    (["vendor", "most", "expired"], vendors_with_most_expired),
    (["contractor", "most", "expired"], vendors_with_most_expired),

    # --- Route analysis ---
    (["top", "route"], top_routes_by_waybills),
    (["route", "ranking"], top_routes_by_waybills),
    (["waybill", "by", "route"], waybill_count_by_route),
    (["waybill", "per", "route"], waybill_count_by_route),
    (["route", "count"], waybill_count_by_route),

    # --- Recent waybills ---
    (["recent", "waybill"], recent_waybills),
    (["latest", "waybill"], recent_waybills),
    (["last", "waybill"], recent_waybills),
    (["newest", "waybill"], recent_waybills),

    # --- Quantity totals ---
    (["total", "requested", "quantity"], total_requested_quantity),
    (["total", "actual", "quantity"], total_actual_quantity),
    (["average", "requested", "quantity"], avg_requested_quantity),
    (["avg", "requested", "quantity"], avg_requested_quantity),
    (["total", "quantity"], total_requested_quantity),

    # --- Plant by quantity ---
    (["plant", "quantity"], plants_by_quantity),
    (["plant", "by", "quantity"], plants_by_quantity),
    (["quantity", "by", "plant"], plants_by_quantity),
]


# --- Parameterized query patterns (extract values from query text) ---

# Waybill number pattern: D6-25-0039536, 1-25-0010844, etc.
_WAYBILL_NUMBER_RE = _re.compile(r'(?:waybill|وصل)\s*(?:number|#|no\.?)?\s*([A-Z0-9]+-\d{2}-\d{5,})', _re.IGNORECASE)

# Plant code pattern: CP01, WP21, SP06, EP02, etc.
_PLANT_CODE_RE = _re.compile(r'(?:plant|محطة)\s+([A-Z]{2}\d{2})', _re.IGNORECASE)

# Status keyword mapping
_STATUS_KEYWORDS = {
    "delivered": "Delivered",
    "cancelled": "Cancelled",
    "canceled": "Cancelled",
    "expired": "Expired",
    "rejected": "Rejected",
    "paid": "Paid",
    "in progress": "In Progress",
    "in-progress": "In Progress",
    # Arabic
    "ملغي": "Cancelled",
    "منتهي": "Expired",
    "مرفوض": "Rejected",
    "مسلم": "Delivered",
    "مدفوع": "Paid",
}


def _match_parameterized_query(query: str) -> str:
    """
    Match parameterized patterns that extract values from the query text.
    Returns SQL string if matched, None otherwise.
    """
    query_lower = query.lower()

    # --- "status of waybill D6-25-0039536" ---
    wb_match = _WAYBILL_NUMBER_RE.search(query)
    if wb_match:
        wb_num = wb_match.group(1).upper()
        return f'SELECT "Waybill Number", "Waybill Status Desc", "Waybill Status Date", "Waybill Status Time", "Vendor Name", "Power Plant Desc", "Route Desc" FROM waybills WHERE "Waybill Number" = \'{wb_num}\';'

    # --- "waybills for plant CP01" ---
    plant_match = _PLANT_CODE_RE.search(query)
    if plant_match:
        plant_code = plant_match.group(1).upper()
        if "count" in query_lower or "how many" in query_lower:
            return f'SELECT COUNT(*) AS waybill_count FROM waybills WHERE "Power Plant" = \'{plant_code}\';'
        return f'SELECT * FROM waybills WHERE "Power Plant" = \'{plant_code}\';'

    # --- "how many waybills are delivered/cancelled/expired" ---
    for keyword, status_value in _STATUS_KEYWORDS.items():
        if keyword in query_lower:
            if any(w in query_lower for w in ["how many", "count", "total", "عدد", "كم"]):
                return f'SELECT COUNT(*) AS {status_value.lower()}_count FROM waybills WHERE "Waybill Status Desc" = \'{status_value}\';'

    return None


def match_fixed_query(query: str) -> str:
    """
    Match a query against fixed patterns using fuzzy keyword matching.
    Returns SQL string if matched, None otherwise.

    This allows natural variations like:
    - "Show waybill count by month" -> matches ["waybill", "count", "month"]
    - "how many waybills does each contractor have" -> matches ["how", "many", "waybill", "each", "contractor"]
    - "status of waybill D6-25-0039536" -> parameterized match (instant)
    """
    # Check exact match first
    if query in FIXED_QUERIES:
        return FIXED_QUERIES[query]

    # Check parameterized patterns (extract values from query)
    parameterized = _match_parameterized_query(query)
    if parameterized:
        return parameterized

    # Fuzzy pattern match
    query_lower = query.lower()
    query_words = set(query_lower.split())

    best_match = None
    best_score = 0
    best_keyword_count = 0

    for keywords, sql in _PATTERN_QUERIES:
        # Check if ALL keywords appear in the query (as substrings for partial matching)
        matched = sum(1 for kw in keywords if kw in query_lower)
        if matched == len(keywords):
            # Prefer higher score; on tie, prefer pattern with more keywords (more specific)
            if matched > best_score or (matched == best_score and len(keywords) > best_keyword_count):
                best_score = matched
                best_match = sql
                best_keyword_count = len(keywords)

    return best_match