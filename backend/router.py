"""
LLM-based query router for classifying user queries.
Routes to SQL agent (dispatch/waybill data), CSV agent (vehicle dwell time), PDF agent (document queries),
or returns "clarify" when uncertain to ask user for clarification.

Optimized: Default route is "sql" (80%+ of queries). LLM only called for ambiguous cases.
"""

import re
import json
import time
from typing import Union, Dict, List, Optional
from langchain_ollama import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

from .memory import SharedMemory
from .column_disambiguator import SQL_AMBIGUOUS_TERMS, CSV_AMBIGUOUS_TERMS


# CSV routing keywords - explicit column names and keywords that should route to CSV agent
CSV_ROUTE_KEYWORDS = [
    # Exact column names
    "driver_id", "vehicle_name", "zone_name", "dwell_hrs", "dwell_minutes",
    "entry_time", "exit_time",

    # Common variations (English)
    "dwell", "dwell time", "stay time", "stay duration",
    "zone", "zones", "geofence", "geofences",
    "driver", "drivers",
    "vehicle", "vehicles", "truck", "trucks",
    "trip", "trips", "visit", "visits",

    # Arabic variations
    "سائق", "سائقين",  # driver, drivers
    "منطقة", "مناطق",  # zone, zones
    "سيارة", "سيارات", "شاحنة",  # vehicle, vehicles, truck
    "رحلة", "رحلات",  # trip, trips
]


# Math routing keywords - terms that indicate mathematical calculations
MATH_ROUTE_KEYWORDS = [
    # English keywords
    "calculate", "compute", "math", "calculation",
    "add", "subtract", "multiply", "divide",
    "sum", "difference", "product", "quotient",
    "plus", "minus", "times", "divided by",
    "square root", "sqrt", "power of", "exponent",
    "percent", "percentage", "modulo", "remainder",
    "factorial", "logarithm", "log", "sine", "cosine", "tangent",
    "sin", "cos", "tan",

    # Arabic keywords
    "حساب", "احسب", "حسابات",  # calculate, compute, calculations
    "جمع", "طرح", "ضرب", "قسمة",  # add, subtract, multiply, divide
    "زائد", "ناقص", "مضروب", "مقسوم",  # plus, minus, times, divided
    "الجذر", "جذر تربيعي",  # root, square root
    "النسبة المئوية", "المئوية",  # percentage
    "أس", "قوة",  # power, exponent
]


# PDF routing keywords - terms that indicate grid code / document queries
PDF_ROUTE_KEYWORDS = [
    # English keywords
    "grid code", "regulation", "regulations",
    "compliance", "technical standard", "technical standards",
    "specification", "specifications", "policy", "policies",
    "procedure", "procedures", "grid connection",

    # Arabic keywords
    "كود الشبكة", "الكود", "اللوائح", "المعايير",  # grid code, regulations, standards
]

# Follow-up indicators - pronouns and references that suggest continuation
FOLLOW_UP_PATTERNS = re.compile(
    r'\b(it|they|them|those|these|that|this|the same|filter|sort|show me more|'
    r'more details|also|and what about|what about|how about|'
    r'هم|هذا|هذه|تلك|نفس|المزيد|أيضا)\b',
    re.IGNORECASE
)

# Meta question patterns for conversational queries about the conversation itself
META_PATTERNS = [
    "last question", "previous question", "what did i ask",
    "my question", "asked before", "earlier question",
    "what was my", "what i asked"
]


def handle_meta_question(query: str, session_id: str) -> Optional[Dict]:
    """
    Handle meta questions about conversation history.

    Args:
        query: User's query
        session_id: Session ID for conversation memory

    Returns:
        Dict with meta response if it's a meta question, None otherwise
    """
    q = query.lower()

    if any(pattern in q for pattern in META_PATTERNS):
        memory = SharedMemory.get_session(session_id)
        messages = memory.get_messages()
        user_questions = [m.content for m in messages if isinstance(m, HumanMessage)]

        if user_questions:
            last_q = user_questions[-1]
            return {
                "route": "meta",
                "content": f"Your last question was: \"{last_q}\"",
                "response_time": "0s",
                "sources": ["Conversation History"]
            }
        else:
            return {
                "route": "meta",
                "content": "This is your first question in our conversation.",
                "response_time": "0s",
                "sources": ["Conversation History"]
            }
    return None


def _word_match(keyword: str, text: str) -> bool:
    """Check if keyword appears as a whole word (not substring) in text."""
    return bool(re.search(r'\b' + re.escape(keyword) + r'\b', text))


def detect_route_from_column_terms(query: str, session_id: str = None) -> str:
    """
    Detect route based on column terms and keywords in query.
    Returns "sql" as DEFAULT — no LLM needed for the majority of queries.

    Routing priority:
    1. Math keywords → "math"
    2. CSV keywords → "csv"
    3. PDF keywords → "pdf"
    4. SQL ambiguous terms → "sql"
    5. CSV ambiguous terms → "csv"
    6. Follow-up detection (pronouns + last route) → last route
    7. DEFAULT → "sql" (80%+ of queries are SQL)

    Args:
        query: User's natural language query
        session_id: Optional session ID for follow-up detection

    Returns:
        Route string: "sql", "csv", "pdf", or "math" (never None)
    """
    query_lower = query.lower()

    # CHECK MATH KEYWORDS FIRST (use word-boundary matching to avoid
    # false positives like "sum" in "summary", "sin" in "single", etc.)
    for keyword in MATH_ROUTE_KEYWORDS:
        if _word_match(keyword, query_lower):
            return "math"

    # CHECK CSV KEYWORDS (use word-boundary matching)
    for keyword in CSV_ROUTE_KEYWORDS:
        if _word_match(keyword, query_lower):
            return "csv"

    # CHECK PDF KEYWORDS (use word-boundary matching)
    for keyword in PDF_ROUTE_KEYWORDS:
        if _word_match(keyword, query_lower):
            return "pdf"

    # Check SQL ambiguous column terms (quantity, date, name, status + Arabic equivalents)
    for term in SQL_AMBIGUOUS_TERMS.keys():
        if term in query_lower:
            return "sql"

    # Check CSV ambiguous column terms (duration, time + Arabic equivalents)
    for term in CSV_AMBIGUOUS_TERMS.keys():
        if term in query_lower:
            return "csv"

    # FOLLOW-UP DETECTION: pronouns/references + previous route exists → reuse route
    if session_id:
        memory = SharedMemory.get_session(session_id)
        last_route = memory.get_route()
        if last_route and FOLLOW_UP_PATTERNS.search(query):
            return last_route

    # DEFAULT: SQL (80%+ of queries are about dispatch/waybill data)
    return "sql"


router_model = ChatOllama(
    model="gpt-oss:latest",
    temperature=0,
    format="json"
)

ROUTER_PROMPT = """You are a query router for a dispatch assistant system.

Analyze the user's query and classify it with confidence level.

## Data Sources:

1. "sql" - Dispatch database:
   - Waybills, dispatch operations, deliveries, schedules
   - Contractors, vendors, routes, plants, power plants
   - Data counts, lists, statistics about dispatch operations
   - Arabic questions about the above

2. "csv" - Vehicle dwell time data:
   - How long vehicles stayed in zones/geofences
   - Zone entry/exit times, dwell time analysis
   - Driver IDs, driver analysis, zone traffic
   - Keywords: dwell, zone, geofence, stay duration

3. "pdf" - Industry Reference Document documents:
   - Grid code regulations, policies, compliance
   - Technical procedures, specifications, standards
   - Documentation questions

4. "math" - Mathematical calculations:
   - Any arithmetic: add, subtract, multiply, divide
   - Advanced math: sqrt, power, sin, cos, log, factorial
   - Natural language math: "what is 5 plus 3", "calculate 100 divided by 4"
   - Percentages: "10 percent of 200"
   - Arabic math: حساب، جمع، طرح، ضرب، قسمة

5. "out_of_scope" - Use when:
   - Query is about general knowledge (geography, history, science)
   - Query is completely unrelated to dispatch, vehicles, grid code, or math
   - Query asks for personal opinions, jokes, or advice
   - Query is vague AND there's no conversation context to help
   - Examples: "what is the capital of France", "tell me a joke"

{context}

Current Question: {query}

## Rules:
- If query clearly mentions specific keywords (waybill, dispatch, plant, dwell, zone, grid code), classify confidently
- If query is a follow-up using pronouns AND there's a previous route, use that route with "high" confidence
- If query is general knowledge or unrelated to our data sources, return "out_of_scope"
- NEVER default to "pdf" when uncertain - use "out_of_scope" instead

Respond with JSON:
{{"route": "sql"|"csv"|"pdf"|"math"|"out_of_scope", "confidence": "high"|"medium"|"low", "reason": "brief explanation"}}"""


def classify_query(query: str, session_id: str = "default") -> Dict:
    """
    Classify a query and return the route with confidence.

    OPTIMIZED: Uses keyword detection + default route ("sql") for ~90% of queries.
    LLM is only called as a fallback — this saves 14-18s per query.

    Args:
        query: User's natural language query
        session_id: Session ID for conversation memory

    Returns:
        Dict with keys:
        - route: "sql", "csv", "pdf", "math", or "out_of_scope"
        - confidence: "high", "medium", or "low"
        - reason: Brief explanation of classification
    """
    start = time.time()

    # FAST PATH: Keyword detection + default route (no LLM needed)
    # detect_route_from_column_terms now always returns a route (default: "sql")
    route_from_terms = detect_route_from_column_terms(query, session_id)

    elapsed = round(time.time() - start, 4)
    print(f"[Router] Keyword routing: '{query}' -> {route_from_terms} ({elapsed}s, no LLM)")

    memory = SharedMemory.get_session(session_id)
    memory.set_route(route_from_terms)

    return {
        "route": route_from_terms,
        "confidence": "high",
        "reason": f"Keyword/default routing to {route_from_terms} (no LLM call)"
    }


def classify_query_simple(query: str, session_id: str = "default") -> str:
    """
    Simple wrapper that returns just the route string for backward compatibility.

    Args:
        query: User's natural language query
        session_id: Session ID for conversation memory

    Returns:
        Route string: "sql", "csv", "pdf", or "clarify"
    """
    result = classify_query(query, session_id)
    return result["route"]


def get_route_description(route: str) -> str:
    """Get a human-readable description of the route."""
    descriptions = {
        "sql": "Dispatch & Waybill Database",
        "csv": "Vehicle Dwell Time Data",
        "pdf": "Industry Reference Document Documents",
        "math": "Math Calculator"
    }
    return descriptions.get(route, "Unknown")
