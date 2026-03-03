import sqlite3
import json
import time
import pandas as pd
import os
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from langchain_ollama import ChatOllama
from langchain.messages import HumanMessage, AIMessage, SystemMessage

# Get the directory where this file is located
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Database is in parent directory
DB_PATH = os.path.join(BASE_DIR, "..", "all_waybills.db")

model = ChatOllama(
    model="gpt-oss:latest",
    temperature=0,
    format="json"
)

def get_table_schema(db_path, table_name="waybills"):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?;",
        (table_name,)
    )
    result = cursor.fetchone()
    conn.close()

    if result is None:
        raise ValueError(f"Table '{table_name}' not found in database: {db_path}")

    return result[0]

def execute_sql(db_path, sql, timeout=30):
    """Execute SQL query with timeout protection."""
    conn = sqlite3.connect(db_path, timeout=timeout)
    cursor = conn.cursor()

    try:
        cursor.execute(sql)
        rows = cursor.fetchall()
        col_names = [d[0] for d in cursor.description]
        conn.close()

        # Limit rows to prevent memory issues (max 5000 rows)
        if len(rows) > 5000:
            rows = rows[:5000]

        return {
            "columns": col_names,
            "rows": rows,
            "truncated": len(rows) == 5000
        }

    except Exception as e:
        conn.close()
        return {"error": str(e), "sql": sql}


def query_to_df(query):
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query(query, conn)
    conn.close()
    return df


def is_scalar_result(result: dict) -> bool:
    """Check if SQL result is scalar (1 row x 1 column)"""
    if "error" in result:
        return False
    rows = result.get("rows", [])
    columns = result.get("columns", [])
    return len(rows) == 1 and len(columns) == 1


def generate_scalar_response(question: str, column_name: str, value) -> str:
    """
    Generate natural language response for scalar result using TEMPLATE (no LLM).
    Saves 14-18s per scalar query by avoiding an LLM call for a simple value display.
    """
    # Format the column name for display (e.g. "Requested Quantity" -> "Requested Quantity")
    col_display = column_name.replace("_", " ")

    # Format value (add commas to numbers)
    if isinstance(value, (int, float)):
        if isinstance(value, float) and value == int(value):
            formatted_value = f"{int(value):,}"
        elif isinstance(value, float):
            formatted_value = f"{value:,.2f}"
        else:
            formatted_value = f"{value:,}"
    else:
        formatted_value = str(value)

    return f"The {col_display} is **{formatted_value}**"


def generate_table_summary(question: str, columns: list, row_count: int) -> str:
    """
    Generate attractive summary text for table results using TEMPLATE (no LLM).
    Saves 14-18s per table query by avoiding an LLM call for a simple summary.
    """
    # Format column names for display
    col_display = ", ".join(col.replace("_", " ") for col in columns[:5])
    if len(columns) > 5:
        col_display += f" (+{len(columns) - 5} more)"

    return f"Found **{row_count:,}** records with: {col_display}"


schema = get_table_schema(DB_PATH)

system_prompt = f"""
You are a bilingual (Arabic + English) SQLite SQL expert.
Your job is to convert natural-language questions into VALID SQLite SQL queries
that operate ONLY on the `waybills` table.

Use ONLY the columns that exist in the schema below.

=====================
WAYBILLS TABLE SCHEMA
{schema}
=====================

### COLUMN DISAMBIGUATION (VERY IMPORTANT)

The database has multiple columns with similar names. Use these rules:

#### Plant-Related Columns:
- SHORT CODES like "CP01", "WP21", "SP06", "EP02" → Use `"Power Plant"` column (exact match with =)
- PLANT DESCRIPTIONS starting with "SEC Transportation" → Use `"Plant Desc"` column
- PLANT NAMES like "Wadi Adawasir", "Hail 2", "Tabuk" → Use `"Power Plant Desc"` column

When user mentions a plant with a CODE (letters + numbers like CP01, WP21):
- "plant CP01" → Use: WHERE "Power Plant" = 'CP01'
- "for CP01" → Use: WHERE "Power Plant" = 'CP01'
- "power plant CP01" → Use: WHERE "Power Plant" = 'CP01'

When user mentions a plant with a NAME:
- "power plant Wadi" → Use: WHERE LOWER("Power Plant Desc") LIKE '%wadi%'
- "plant Hail" → Use: WHERE LOWER("Power Plant Desc") LIKE '%hail%'

#### Quantity-Related Columns:
- "requested quantity", "quantity requested", "طلبية" → Use `"Requested Quantity"` column
- "actual quantity", "الكمية الفعلية" → Use `"Actual Quantity"` column

#### Common Aliases:
- "plant" + CODE (CP01, WP21, etc.) → `"Power Plant"`
- "vendor", "contractor", "company", "مقاول" → `"Vendor Name"`
- "route", "route code", "مسار" → `"Route Code"` or `"Route Desc"`
- "status", "waybill status", "حالة" → `"Waybill Status Desc"`

---

### GENERAL RULES
- Understand Arabic and English queries.
- Output MUST be valid JSON.
- JSON format MUST be exactly:
  {{"sql": "<SQLite_QUERY>"}}
- The value of "sql" MUST be a string containing ONLY the SQL query.
- Do NOT add explanations.
- Do NOT wrap SQL in markdown or ```sql blocks.
- Do NOT return anything other than JSON.
- Do NOT invent column names; use EXACT names from schema.
- Generate a single SELECT query only.
- Never generate INSERT, UPDATE, DELETE, DROP, or ALTER.

---

### CRITICAL STRING MATCHING RULES (VERY IMPORTANT)

#### Vendor / Company / Human Names (CRITICAL)
- NEVER use equality (=) when filtering by names.
- ALWAYS use case-insensitive partial matching with LOWER(column).
- Extract ONLY the 2-3 most distinctive name parts (usually first name + family name).
- NEVER include common business suffixes in patterns: co, ltd, company, cont, tran, trading, sons, est, corp, inc
- Keep the pattern SHORT and SIMPLE - fewer tokens = better matching.
- Preserve hyphens in names exactly as written (e.g., al-rodhan, al-ghannam).
- Skip single-letter initials (like "A.", "M.") in patterns.

WRONG patterns (too restrictive, may return 0 results):
- '%mohammed%al-rodhan%co%ltd%' (includes business suffixes - NEVER do this)
- '%abdul%karim%a%alsudais%' (includes single-letter initials)
- '%mohammed%a%al-rodhan%' (includes "a" initial)

CORRECT patterns (simple, reliable):
- '%mohammed%al-rodhan%' (just first name + family name with hyphen preserved)
- '%abdul%karim%alsudais%' (skip initials, keep main names)
- '%zaid%ghannam%' (first and family name only)

Example:
User: "waybills for MOHAMMED A.AL-RODHAN CO. LTD."
CORRECT: WHERE LOWER("Vendor Name") LIKE '%mohammed%al-rodhan%'
WRONG: WHERE LOWER("Vendor Name") LIKE '%mohammed%a%al-rodhan%co%ltd%'

---

### STATUS FIELDS
- When filtering by "Waybill Status Desc", use exact known values.
- Example: 'Cancelled', 'Paid', 'Expired'.

---

### NON-SQL QUESTIONS
If the user asks a question NOT related to SQL, the waybills table, or available data,
return EXACTLY:

{{"sql": "UNSUPPORTED_REQUEST: I can only answer questions related to SQL and the provided data source."}}

---

### JSON OUTPUT EXAMPLES

User: "هات كل الوابيل اللي كانت Cancelled"
Return ONLY:
{{"sql": "SELECT * FROM waybills WHERE \"Waybill Status Desc\" = 'Cancelled';"}}

User: "ما اكثر مصنع موجود عندنا"
Return ONLY:
{{"sql": "SELECT \"Plant Desc\" FROM waybills GROUP BY \"Plant Desc\" ORDER BY COUNT(*) DESC LIMIT 1;"}}

User: "عايز كل الفواتير اللي تخص هذا البائع ZAID M. AL-GHANNAM"
Return ONLY:
{{"sql": "SELECT * FROM waybills WHERE LOWER(\"Vendor Name\") LIKE '%zaid%ghannam%';"}}

### DISAMBIGUATION EXAMPLES (Plant Codes)

User: "total Requested Quantity for plant CP01"
Return ONLY:
{{"sql": "SELECT SUM(\"Requested Quantity\") FROM waybills WHERE \"Power Plant\" = 'CP01';"}}

User: "waybills for plant WP21"
Return ONLY:
{{"sql": "SELECT * FROM waybills WHERE \"Power Plant\" = 'WP21';"}}

User: "show data for CP01"
Return ONLY:
{{"sql": "SELECT * FROM waybills WHERE \"Power Plant\" = 'CP01';"}}

User: "count waybills for plant SP06"
Return ONLY:
{{"sql": "SELECT COUNT(*) FROM waybills WHERE \"Power Plant\" = 'SP06';"}}

Now wait for the user question.
"""


# --- Timeout wrapper for LLM calls ---

_timeout_executor = ThreadPoolExecutor(max_workers=4)


def invoke_with_timeout(messages: list, timeout: int = 120):
    """
    Invoke the LLM model with a timeout.
    Prevents hung queries (e.g., 70,000s) by killing after `timeout` seconds.

    Args:
        messages: List of langchain messages to send to the model
        timeout: Maximum seconds to wait (default: 120)

    Returns:
        LLM response object

    Raises:
        TimeoutError: If LLM doesn't respond within timeout
    """
    future = _timeout_executor.submit(model.invoke, messages)
    try:
        return future.result(timeout=timeout)
    except FuturesTimeoutError:
        raise TimeoutError(f"LLM call timed out after {timeout}s")


# --- Timing logger ---

def log_timing(step: str, duration: float, extra: str = ""):
    """
    Log timing for a pipeline step.

    Args:
        step: Name of the step (e.g., "router", "sql_gen", "sql_exec", "summary")
        duration: Duration in seconds
        extra: Optional extra info
    """
    msg = f"[Timing] {step}: {duration:.2f}s"
    if extra:
        msg += f" | {extra}"
    print(msg)


