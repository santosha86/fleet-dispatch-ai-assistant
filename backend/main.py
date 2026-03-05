import math
import time
import asyncio
import threading

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional, Any, Dict
import logging
import json
import uuid

from .utils import *
from .fixed_queries import FIXED_QUERIES
from .langgraph_workflow import run_workflow, get_route_for_query
from .agents.pdf_agent_wrapper import stream_pdf_agent
from .memory import SharedMemory

# --- In-memory result cache for pagination ---
# Dict keyed by result_id -> { "columns": [...], "rows": [...], "created_at": float }
_result_cache: Dict[str, dict] = {}
_cache_lock = threading.Lock()
_CACHE_TTL_SECONDS = 30 * 60  # 30 minutes
_DEFAULT_PAGE_SIZE = 100


def _cache_cleanup():
    """Remove expired entries from the result cache."""
    now = time.time()
    with _cache_lock:
        expired = [k for k, v in _result_cache.items()
                   if now - v["created_at"] > _CACHE_TTL_SECONDS]
        for k in expired:
            del _result_cache[k]


def _cache_store(columns: list, rows: list) -> str:
    """Store full result set and return a result_id."""
    _cache_cleanup()
    result_id = str(uuid.uuid4())
    with _cache_lock:
        _result_cache[result_id] = {
            "columns": columns,
            "rows": rows,
            "created_at": time.time(),
        }
    return result_id


def _cache_get_page(result_id: str, page: int, page_size: int) -> Optional[dict]:
    """Retrieve a page from the cached result set."""
    with _cache_lock:
        entry = _result_cache.get(result_id)
    if entry is None:
        return None
    rows = entry["rows"]
    total = len(rows)
    total_pages = max(1, math.ceil(total / page_size))
    start = (page - 1) * page_size
    end = start + page_size
    return {
        "columns": entry["columns"],
        "rows": rows[start:end],
        "total_row_count": total,
        "page": page,
        "total_pages": total_pages,
        "page_size": page_size,
        "result_id": result_id,
    }

class EndpointFilter(logging.Filter):
    def filter(self, record):
        return "socket.io" not in record.getMessage()

logging.getLogger("uvicorn.access").addFilter(EndpointFilter())

app = FastAPI(title="Fleet Dispatch AI Assistant API", version="1.0.0")

# React production build directory
_dist_dir = Path(__file__).resolve().parent.parent / "dist"
_web_enabled = _dist_dir.is_dir()

# CORS middleware for frontend access
# For production, replace ["*"] with specific domains
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Authentication ---
USERS = {
    "pb": "admin1234",
    "user1": "user1pass",
    "user2": "user2pass",
    "user3": "user3pass",
    "user4": "user4pass",
}


class LoginRequest(BaseModel):
    username: str
    password: str


class ComparisonItem(BaseModel):
    text: str
    type: str


class ProcessComparison(BaseModel):
    old_way: List[str]
    new_way: List[str]


class BusinessValueRow(BaseModel):
    metric: str
    before: str
    after: str


class KeyMetric(BaseModel):
    value: str
    label: str


class Capability(BaseModel):
    icon: str
    label: str


class AIAssistantOverview(BaseModel):
    process_comparison: ProcessComparison
    business_value: List[BusinessValueRow]
    key_metrics: List[KeyMetric]
    capabilities: List[Capability]
    language_support: str


class UsageStatsData(BaseModel):
    queries_processed: int
    user_satisfaction: str
    avg_response_time: str
    unique_users: int
    top_categories: dict


class QueryItem(BaseModel):
    text: str


class Category(BaseModel):
    id: str
    label: str
    icon: str
    queries: List[str]


class UserQuery(BaseModel):
    query: str
    session_id: Optional[str] = None
    route: Optional[str] = None
    max_rows: Optional[int] = None  # Client can request row limit (e.g., mobile = 200)
    page_size: Optional[int] = None  # Page size for pagination (default: 100)


class TableData(BaseModel):
    columns: List[str]
    rows: List[List[Any]]
    total_row_count: Optional[int] = None  # Total rows before truncation
    truncated: bool = False  # Whether rows were truncated
    result_id: Optional[str] = None  # Pagination: ID for fetching more pages
    page: Optional[int] = None  # Pagination: current page number (1-based)
    total_pages: Optional[int] = None  # Pagination: total number of pages
    page_size: Optional[int] = None  # Pagination: rows per page


class VisualizationConfig(BaseModel):
    should_visualize: bool
    chart_type: Optional[str] = None  # "bar", "line", "pie", "horizontal_bar", "grouped_bar"
    x_axis: Optional[str] = None
    y_axis: Optional[str] = None
    y_axis_secondary: Optional[str] = None  # For grouped bar charts
    y_axis_list: Optional[List[str]] = None  # For 3+ numeric columns (wide format data)
    group_by: Optional[str] = None  # Column to group/pivot data by (for multi-category comparisons)
    title: Optional[str] = None


class DisambiguationOption(BaseModel):
    value: str
    display: str
    description: Optional[str] = None


class ClarificationOption(BaseModel):
    value: str
    label: str
    description: Optional[str] = None


class QueryResponse(BaseModel):
    content: str
    response_time: str
    sources: List[str]
    table_data: Optional[TableData] = None
    sql_query: Optional[str] = None
    needs_disambiguation: bool = False
    disambiguation_options: Optional[List[DisambiguationOption]] = None
    # Clarification fields for route selection
    needs_clarification: bool = False
    clarification_message: Optional[str] = None
    clarification_options: Optional[List[ClarificationOption]] = None
    # Visualization configuration
    visualization: Optional[VisualizationConfig] = None



AI_OVERVIEW_DATA = AIAssistantOverview(
    process_comparison=ProcessComparison(
        old_way=[
            "Multiple Excel files",
            "Wait for analysts",
            "Manual pivot tables",
            "2-4 hours response"
        ],
        new_way=[
            "Natural language",
            "2-3 second response",
            "Real-time data",
            "24/7 availability"
        ]
    ),
    business_value=[
        BusinessValueRow(metric="Response", before="2-4 hrs", after="2-3 sec"),
        BusinessValueRow(metric="Availability", before="Office hrs", after="24/7")
    ],
    key_metrics=[
        KeyMetric(value="50-60%", label="Faster"),
        KeyMetric(value="75%+", label="Accuracy"),
        KeyMetric(value="20-30%", label="Cost Savings"),
        KeyMetric(value="94%", label="Satisfaction")
    ],
    capabilities=[
        Capability(icon="search", label="Query & Search"),
        Capability(icon="chart", label="Analyze & Compare"),
        Capability(icon="lightbulb", label="Explain & Recommend"),
        Capability(icon="trending", label="Summarize & Forecast")
    ],
    language_support="English & Arabic Support"
)

USAGE_STATS_DATA = UsageStatsData(
    queries_processed=847,
    user_satisfaction="94%",
    avg_response_time="2.3s",
    unique_users=32,
    top_categories={
        "Operations & Dispatch": "35%",
        "Contractor Performance": "25%",
        "Management Reports": "20%",
        "Finance & Root Cause": "20%"
    }
)

# Get query keys from FIXED_QUERIES
QUERY_KEYS = list(FIXED_QUERIES.keys())

CATEGORIES_DATA = [
    Category(
        id="ops",
        label="Operations",
        icon="Truck",
        queries=[QUERY_KEYS[0], QUERY_KEYS[1]]  # Show today's dispatch, List all active
    ),
    Category(
        id="waybills",
        label="Waybills",
        icon="FileText",
        queries=[QUERY_KEYS[2], QUERY_KEYS[3]]  # Status of waybill, Details of waybill
    ),
    Category(
        id="contractors",
        label="Contractors",
        icon="Users",
        queries=[QUERY_KEYS[4], QUERY_KEYS[5]]  # Waybills for contractor, Contractor-wise list
    ),
    Category(
        id="Status Inquiry",
        label="Status",
        icon="TrendingUp",
        queries=[QUERY_KEYS[6], QUERY_KEYS[7]]  # Route details, Waybills on route
    )
]

MOCK_RESPONSES = {
    "Which contractor caused most delays?": {
        "content": "Based on the analysis of Q3 data, **LogiTrans Corp** accounts for **32%** of all reported delays, primarily due to vehicle breakdown issues on the Northern Route.",
        "response_time": "0.8s",
        "sources": ["ODW Online", "SAP Finance"]
    },
    "Why was Waybill 784 late?": {
        "content": "**Waybill 784** was delayed by **45 minutes**. The root cause was identified as *Wait for Load* at the distribution center. The driver arrived at 08:00, but loading commenced at 08:45.",
        "response_time": "0.7s",
        "sources": ["ODW Online", "Telematics"]
    },
    "Summarize today's delayed dispatches": {
        "content": "Today, there are **14 delayed dispatches**. \n\n*   **Top Reason:** Traffic Congestion (8)\n*   **Secondary:** Documentation Issues (4)\n*   **Other:** Mechanical (2)\n\nAverage delay time: 22 minutes.",
        "response_time": "0.9s",
        "sources": ["ODW Online", "Fleet Management"]
    },
    "Show me pending reconciliations": {
        "content": "There are currently **23 pending reconciliations** awaiting approval.\n\n*   **Operations:** 12\n*   **Finance:** 8\n*   **Disputes:** 3\n\nMost are aged < 48 hours.",
        "response_time": "0.6s",
        "sources": ["SAP Finance", "ODW Online"]
    },
    "Top 5 delay reasons this week": {
        "content": "**Top 5 Delay Reasons (Current Week):**\n1.  Traffic / Route Congestion (35%)\n2.  Loading Dock Wait Time (22%)\n3.  Driver Unavailability (15%)\n4.  Documentation Errors (12%)\n5.  Vehicle Breakdown (10%)",
        "response_time": "0.8s",
        "sources": ["ODW Online", "Telematics"]
    },
    "Compare contractor performance Q3": {
        "content": "**Q3 Performance Summary:**\n\n*   **FastTrack Logistics:** 98% On-Time (Top Performer)\n*   **Global Freight:** 92% On-Time\n*   **LogiTrans Corp:** 85% On-Time (Requires Review)\n\nFastTrack has improved efficiency by 5% since Q2.",
        "response_time": "1.0s",
        "sources": ["ODW Online", "SAP Finance"]
    }
}



@app.post("/api/login")
async def login(request: LoginRequest):
    """Validate user credentials."""
    username = request.username.strip().lower()
    if USERS.get(username) == request.password:
        return {"success": True, "username": username}
    raise HTTPException(status_code=401, detail="Invalid username or password")


@app.get("/")
async def root():
    if _web_enabled:
        return FileResponse(_dist_dir / "index.html")
    return {"message": "Fleet Dispatch AI Assistant API", "version": "1.0.0"}


@app.get("/api/ai-overview", response_model=AIAssistantOverview)
async def get_ai_overview():
    """Get AI Assistant Overview data for the InfoPanel"""
    return AI_OVERVIEW_DATA


@app.get("/api/usage-stats", response_model=UsageStatsData)
async def get_usage_stats():
    """Get usage statistics data"""
    return USAGE_STATS_DATA


@app.get("/api/categories", response_model=List[Category])
async def get_categories():
    """Get query categories and their sample questions"""
    return CATEGORIES_DATA


@app.get("/api/categories/{category_id}/queries", response_model=List[str])
async def get_category_queries(category_id: str):
    """Get questions for a specific category"""
    for category in CATEGORIES_DATA:
        if category.id == category_id:
            return category.queries
    return []


@app.post("/api/query", response_model=QueryResponse)
async def process_query(user_query: UserQuery):
    """
    Process a user query through the LangGraph workflow.
    Routes to SQL agent for dispatch/waybill queries, PDF agent for document queries.
    Supports forced route from clarification flow.
    """
    query_text = user_query.query.strip()
    session_id = user_query.session_id or str(uuid.uuid4())
    forced_route = user_query.route  # Optional forced route from clarification

    if query_text in MOCK_RESPONSES:
        response_data = MOCK_RESPONSES[query_text]
        return QueryResponse(
            content=response_data["content"],
            response_time=response_data["response_time"],
            sources=response_data["sources"]
        )

    # Run through LangGraph workflow (with optional forced route)
    # Use asyncio.to_thread to avoid blocking the event loop with synchronous LangGraph
    result = await asyncio.to_thread(run_workflow, query_text, session_id, forced_route)

    # Build disambiguation options if present
    disambiguation_options = None
    if result.get("disambiguation_options"):
        disambiguation_options = [
            DisambiguationOption(**opt) for opt in result["disambiguation_options"]
        ]

    # Build clarification options if present
    clarification_options = None
    if result.get("clarification_options"):
        clarification_options = [
            ClarificationOption(**opt) for opt in result["clarification_options"]
        ]

    # Build visualization config if present
    visualization = None
    if result.get("visualization"):
        visualization = VisualizationConfig(**result["visualization"])

    # Build table_data with pagination for large results
    table_data_obj = None
    if result["table_data"]:
        td = result["table_data"]
        all_rows = td["rows"]
        total_count = len(all_rows)
        page_size = user_query.page_size or _DEFAULT_PAGE_SIZE

        if total_count > page_size:
            # Cache full result and return only page 1
            result_id = _cache_store(td["columns"], all_rows)
            total_pages = math.ceil(total_count / page_size)
            table_data_obj = TableData(
                columns=td["columns"],
                rows=all_rows[:page_size],
                total_row_count=total_count,
                truncated=False,
                result_id=result_id,
                page=1,
                total_pages=total_pages,
                page_size=page_size,
            )
        else:
            table_data_obj = TableData(
                columns=td["columns"],
                rows=all_rows,
                total_row_count=total_count,
            )

    return QueryResponse(
        content=result["content"] or "No response generated",
        response_time=result["response_time"] or "0s",
        sources=result["sources"] or ["System"],
        table_data=table_data_obj,
        sql_query=result["sql_query"],
        needs_disambiguation=result.get("needs_disambiguation", False) or False,
        disambiguation_options=disambiguation_options,
        needs_clarification=result.get("needs_clarification", False) or False,
        clarification_message=result.get("clarification_message"),
        clarification_options=clarification_options,
        visualization=visualization
    )


@app.post("/api/query/stream")
async def process_query_stream(user_query: UserQuery):
    """
    Streaming endpoint for queries.
    Uses Server-Sent Events (SSE) format.
    - PDF queries stream with phases (planning, retrieval, reasoning, answer)
    - SQL/CSV queries return immediately as single SSE message
    - Clarify requests return options for user to select
    """
    query_text = user_query.query.strip()
    session_id = user_query.session_id or str(uuid.uuid4())

    # Use provided route or classify (avoid double classification from frontend)
    route = user_query.route or await asyncio.to_thread(get_route_for_query, query_text, session_id)

    if route in ("greeting", "out_of_scope"):
        # Instant response — no LLM needed, run through workflow
        result = await asyncio.to_thread(run_workflow, query_text, session_id, route)

        async def instant_response():
            data = {
                "content": result["content"] or "No response generated",
                "done": True,
                "response_time": result["response_time"] or "0s",
                "sources": result["sources"] or ["System"],
                "table_data": None,
                "sql_query": None,
                "needs_disambiguation": False,
                "disambiguation_options": None,
                "needs_clarification": False,
                "clarification_message": None,
                "clarification_options": None,
                "visualization": None
            }
            yield f"data: {json.dumps(data)}\n\n"

        return StreamingResponse(
            instant_response(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )

    if route == "pdf":
        # Stream PDF agent response
        return StreamingResponse(
            stream_pdf_agent(query_text, session_id),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )
    else:
        # For SQL/CSV/clarify, run in thread to avoid blocking event loop
        result = await asyncio.to_thread(run_workflow, query_text, session_id, route)

        # Apply pagination for large results
        table_data_resp = result["table_data"]
        if table_data_resp:
            all_rows = table_data_resp.get("rows", [])
            total_count = len(all_rows)
            page_size = user_query.page_size or _DEFAULT_PAGE_SIZE

            if total_count > page_size:
                result_id = _cache_store(table_data_resp["columns"], all_rows)
                total_pages = math.ceil(total_count / page_size)
                table_data_resp = {
                    **table_data_resp,
                    "rows": all_rows[:page_size],
                    "total_row_count": total_count,
                    "truncated": False,
                    "result_id": result_id,
                    "page": 1,
                    "total_pages": total_pages,
                    "page_size": page_size,
                }
            else:
                table_data_resp = {
                    **table_data_resp,
                    "total_row_count": total_count,
                }

        async def single_response():
            data = {
                "content": result["content"] or "No response generated",
                "done": True,
                "response_time": result["response_time"] or "0s",
                "sources": result["sources"] or ["System"],
                "table_data": table_data_resp,
                "sql_query": result["sql_query"],
                "needs_disambiguation": result.get("needs_disambiguation", False) or False,
                "disambiguation_options": result.get("disambiguation_options"),
                "needs_clarification": result.get("needs_clarification", False) or False,
                "clarification_message": result.get("clarification_message"),
                "clarification_options": result.get("clarification_options"),
                "visualization": result.get("visualization")
            }
            yield f"data: {json.dumps(data)}\n\n"

        return StreamingResponse(
            single_response(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )


@app.get("/api/table-data/{result_id}", response_model=TableData)
async def get_table_data_page(result_id: str, page: int = 1, page_size: int = _DEFAULT_PAGE_SIZE):
    """Fetch a specific page from a cached query result."""
    if page < 1:
        raise HTTPException(status_code=400, detail="Page must be >= 1")
    if page_size < 1 or page_size > 1000:
        raise HTTPException(status_code=400, detail="page_size must be between 1 and 1000")

    result = _cache_get_page(result_id, page, page_size)
    if result is None:
        raise HTTPException(status_code=404, detail="Result not found or expired")

    return TableData(**result)


class SessionClear(BaseModel):
    session_id: str


@app.post("/api/route")
async def get_query_route(user_query: UserQuery):
    """Return the route classification for a query (sql, csv, or pdf)."""
    session_id = user_query.session_id or "default"
    route = await asyncio.to_thread(get_route_for_query, user_query.query.strip(), session_id)
    return {"route": route}


@app.post("/api/session/clear")
async def clear_session(request: SessionClear):
    """Clear conversation history for a session."""
    SharedMemory.clear_session(request.session_id)
    return {"status": "cleared", "session_id": request.session_id}


# --- APK Download Page ---
_static_dir = Path(__file__).resolve().parent / "static"
_apk_path = _static_dir / "app-release.apk"


@app.get("/download", response_class=HTMLResponse)
async def download_page():
    """Landing page for APK download with install instructions."""
    apk_exists = _apk_path.is_file()
    apk_size = ""
    if apk_exists:
        size_mb = _apk_path.stat().st_size / (1024 * 1024)
        apk_size = f"{size_mb:.1f} MB"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fleet Dispatch - Download</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
               background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
               color: #e2e8f0; min-height: 100vh; display: flex; align-items: center;
               justify-content: center; padding: 20px; }}
        .card {{ background: #1e293b; border-radius: 16px; padding: 40px;
                max-width: 480px; width: 100%; box-shadow: 0 25px 50px rgba(0,0,0,0.4);
                border: 1px solid #334155; text-align: center; }}
        .logo {{ font-size: 48px; margin-bottom: 16px; }}
        h1 {{ font-size: 24px; color: #f8fafc; margin-bottom: 8px; }}
        .version {{ color: #94a3b8; font-size: 14px; margin-bottom: 24px; }}
        .btn {{ display: inline-block; background: linear-gradient(135deg, #3b82f6, #2563eb);
               color: white; padding: 14px 32px; border-radius: 10px; text-decoration: none;
               font-size: 16px; font-weight: 600; transition: transform 0.2s;
               margin-bottom: 8px; }}
        .btn:hover {{ transform: translateY(-2px); }}
        .btn.disabled {{ background: #475569; cursor: not-allowed; }}
        .size {{ color: #94a3b8; font-size: 13px; margin-bottom: 24px; }}
        .steps {{ text-align: left; background: #0f172a; border-radius: 10px;
                 padding: 20px; margin-top: 20px; }}
        .steps h3 {{ color: #60a5fa; font-size: 14px; margin-bottom: 12px; }}
        .steps ol {{ padding-left: 20px; }}
        .steps li {{ color: #cbd5e1; font-size: 13px; line-height: 1.8; }}
        .steps code {{ background: #334155; padding: 2px 6px; border-radius: 4px;
                      font-size: 12px; color: #93c5fd; }}
        .web-link {{ margin-top: 20px; padding-top: 16px; border-top: 1px solid #334155; }}
        .web-link a {{ color: #60a5fa; text-decoration: none; font-size: 14px; }}
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">📱</div>
        <h1>Fleet Dispatch Assistant</h1>
        <p class="version">v1.0.0 &middot; Android</p>
        {'<a href="/download/apk" class="btn">Download APK</a>' if apk_exists else '<span class="btn disabled">APK Not Available</span>'}
        <p class="size">{'Size: ' + apk_size if apk_exists else 'APK file not found on server'}</p>
        <div class="steps">
            <h3>Install Instructions</h3>
            <ol>
                <li>Download the APK file above</li>
                <li>Open <code>Settings &gt; Security</code> on your Android device</li>
                <li>Enable <code>Install from Unknown Sources</code></li>
                <li>Open the downloaded APK and tap <strong>Install</strong></li>
                <li>Login with your provided credentials</li>
            </ol>
        </div>
        <div class="web-link">
            <a href="/">Open Web App Instead &rarr;</a>
        </div>
    </div>
</body>
</html>"""


@app.get("/download/apk")
async def download_apk():
    """Serve the APK file for download."""
    if not _apk_path.is_file():
        raise HTTPException(status_code=404, detail="APK file not found. Build the APK first.")
    return FileResponse(
        path=str(_apk_path),
        filename="fleet-dispatch.apk",
        media_type="application/vnd.android.package-archive",
    )


# --- Serve React production build (if dist/ folder exists) ---
if _web_enabled:
    # Mount static assets directory (JS, CSS, images built by Vite)
    _assets_dir = _dist_dir / "assets"
    if _assets_dir.is_dir():
        app.mount("/assets", StaticFiles(directory=str(_assets_dir)), name="static-assets")

    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        """Catch-all: serve static files from dist/, fallback to index.html for SPA routing."""
        file_path = _dist_dir / full_path
        if full_path and file_path.is_file():
            return FileResponse(file_path)
        return FileResponse(_dist_dir / "index.html")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
