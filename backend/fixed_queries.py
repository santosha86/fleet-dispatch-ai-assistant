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
]


def match_fixed_query(query: str) -> str:
    """
    Match a query against fixed patterns using fuzzy keyword matching.
    Returns SQL string if matched, None otherwise.

    This allows natural variations like:
    - "Show waybill count by month" -> matches ["waybill", "count", "month"]
    - "how many waybills does each contractor have" -> matches ["how", "many", "waybill", "each", "contractor"]
    """
    # Check exact match first
    if query in FIXED_QUERIES:
        return FIXED_QUERIES[query]

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