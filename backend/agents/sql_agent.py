"""
SQL Agent wrapper for the LangGraph workflow.
Handles both fixed queries and LLM-generated SQL.

Optimized: SQL result caching (5-min TTL), per-step timing, LLM timeout protection.
"""

import time
import json
import hashlib
import threading
from typing import Optional, List, Any, Dict
from dataclasses import dataclass, field
from langchain_core.messages import SystemMessage, HumanMessage

# Import from parent package using relative imports
from ..utils import (
    execute_sql,
    is_scalar_result,
    generate_scalar_response,
    generate_table_summary,
    invoke_with_timeout,
    log_timing,
    system_prompt,
    DB_PATH
)
from ..fixed_queries import FIXED_QUERIES, match_fixed_query
from ..memory import SharedMemory
from ..column_disambiguator import (
    detect_sql_disambiguation,
    combine_query_with_disambiguation
)
from ..visualization_detector import detect_visualization, VisualizationConfig


# --- Query Text Cache (skips LLM entirely for repeated questions) ---

_QUERY_CACHE_TTL = 300  # 5 minutes
_query_cache: Dict[str, dict] = {}  # key: query_text_hash -> {"response": SQLAgentResponse dict, "timestamp": ...}
_query_cache_lock = threading.Lock()


def _query_cache_key(query: str) -> str:
    """Generate cache key from normalized query text."""
    return hashlib.md5(query.strip().lower().encode()).hexdigest()


def _get_cached_query_response(query: str) -> Optional[dict]:
    """Get cached full response for a query if still valid."""
    key = _query_cache_key(query)
    with _query_cache_lock:
        entry = _query_cache.get(key)
        if entry and (time.time() - entry["timestamp"]) < _QUERY_CACHE_TTL:
            return entry["response"]
        elif entry:
            del _query_cache[key]  # expired
    return None


def _set_cached_query_response(query: str, response_dict: dict):
    """Cache a full query response (keyed by query text)."""
    key = _query_cache_key(query)
    with _query_cache_lock:
        _query_cache[key] = {"response": response_dict, "timestamp": time.time()}
        # Evict old entries if cache grows too large (max 200)
        if len(_query_cache) > 200:
            oldest_key = min(_query_cache, key=lambda k: _query_cache[k]["timestamp"])
            del _query_cache[oldest_key]


# --- SQL Result Cache (in-memory, TTL: 5 min) ---

_SQL_CACHE_TTL = 300  # 5 minutes
_sql_cache: Dict[str, dict] = {}  # key: sql_hash -> {"result": ..., "timestamp": ...}
_sql_cache_lock = threading.Lock()


def _cache_key(sql: str) -> str:
    """Generate cache key from SQL query."""
    return hashlib.md5(sql.strip().lower().encode()).hexdigest()


def _get_cached_result(sql: str) -> Optional[dict]:
    """Get cached SQL result if still valid (within TTL)."""
    key = _cache_key(sql)
    with _sql_cache_lock:
        entry = _sql_cache.get(key)
        if entry and (time.time() - entry["timestamp"]) < _SQL_CACHE_TTL:
            return entry["result"]
        elif entry:
            del _sql_cache[key]  # expired
    return None


def _set_cached_result(sql: str, result: dict):
    """Cache a SQL result."""
    key = _cache_key(sql)
    with _sql_cache_lock:
        _sql_cache[key] = {"result": result, "timestamp": time.time()}
        # Evict old entries if cache grows too large (max 100)
        if len(_sql_cache) > 100:
            oldest_key = min(_sql_cache, key=lambda k: _sql_cache[k]["timestamp"])
            del _sql_cache[oldest_key]


def _cache_query_response(query: str, response):
    """Cache a successful query response (skip errors and disambiguations)."""
    if response.needs_disambiguation or response.content.startswith("**Error"):
        return
    cache_dict = {
        "content": response.content,
        "sources": response.sources,
        "sql_query": response.sql_query,
        "table_data": response.table_data.to_dict() if response.table_data else None,
        "visualization": response.visualization.to_dict() if response.visualization else None
    }
    _set_cached_query_response(query, cache_dict)


# Key columns to extract for follow-up context
KEY_COLUMNS = [
    "Vendor Name", "Power Plant", "Power Plant Desc", "Plant Desc",
    "Route Code", "Route Desc", "Waybill Status Desc", "Contractor Name"
]


def _extract_result_context(result: dict) -> dict:
    """
    Extract key values from query result for follow-up context.
    This allows follow-up queries to reference entities like "this vendor", "that plant", etc.
    """
    if "error" in result or "rows" not in result:
        return None

    columns = result["columns"]
    rows = result["rows"]

    if not rows:
        return None

    # For single-row results, store all column values
    if len(rows) == 1:
        return {
            "type": "single_result",
            "values": {col: rows[0][i] for i, col in enumerate(columns)}
        }

    # For multi-row results, store count and key column values (first few rows)
    context = {
        "type": "multi_result",
        "count": len(rows),
        "key_values": {}
    }

    for i, col in enumerate(columns):
        if col in KEY_COLUMNS:
            # Store first 5 unique values for key columns
            unique_values = []
            seen = set()
            for row in rows[:10]:
                val = row[i]
                if val and val not in seen:
                    unique_values.append(val)
                    seen.add(val)
                if len(unique_values) >= 5:
                    break
            if unique_values:
                context["key_values"][col] = unique_values if len(unique_values) > 1 else unique_values[0]

    return context if context["key_values"] else None


@dataclass
class TableData:
    """Table data structure."""
    columns: List[str]
    rows: List[List[Any]]

    def to_dict(self) -> dict:
        return {"columns": self.columns, "rows": self.rows}


@dataclass
class DisambiguationOption:
    """Option for disambiguation."""
    value: str
    display: str
    description: str = ""

    def to_dict(self) -> dict:
        return {"value": self.value, "display": self.display, "description": self.description}


@dataclass
class SQLAgentResponse:
    """Response from SQL agent."""
    content: str
    response_time: str
    sources: List[str]
    table_data: Optional[TableData] = None
    sql_query: Optional[str] = None
    needs_disambiguation: bool = False
    disambiguation_options: Optional[List[DisambiguationOption]] = None
    visualization: Optional[VisualizationConfig] = None

    def to_dict(self) -> dict:
        result = {
            "content": self.content,
            "response_time": self.response_time,
            "sources": self.sources,
            "sql_query": self.sql_query,
            "needs_disambiguation": self.needs_disambiguation,
            "disambiguation_options": [opt.to_dict() for opt in self.disambiguation_options] if self.disambiguation_options else None
        }
        if self.table_data:
            result["table_data"] = self.table_data.to_dict()
        else:
            result["table_data"] = None
        if self.visualization:
            result["visualization"] = self.visualization.to_dict()
        else:
            result["visualization"] = None
        return result


def run_sql_agent(query: str, session_id: str = "default") -> SQLAgentResponse:
    """
    Run SQL agent on a query and return structured response.

    Args:
        query: User's natural language query
        session_id: Session ID for conversation memory

    Returns:
        SQLAgentResponse with content, table_data, etc.
    """
    start_time = time.time()
    query_text = query.strip()

    # CHECK 0: Query text cache (fastest path - skips LLM entirely for repeated questions)
    cached_response = _get_cached_query_response(query_text)
    if cached_response:
        elapsed_time = round(time.time() - start_time, 4)
        log_timing("query_cache", elapsed_time, f"CACHE HIT: {query_text[:60]}")
        # Return cached response with updated time
        return SQLAgentResponse(
            content=cached_response["content"],
            response_time=f"{elapsed_time}s",
            sources=cached_response["sources"],
            table_data=TableData(**cached_response["table_data"]) if cached_response.get("table_data") else None,
            sql_query=cached_response.get("sql_query"),
            visualization=VisualizationConfig(**cached_response["visualization"]) if cached_response.get("visualization") else None
        )

    # Get conversation memory for follow-up questions
    memory = SharedMemory.get_session(session_id)
    history = memory.get()  # Get history BEFORE adding current message

    # CHECK 1: Fixed queries — exact match OR fuzzy pattern match (no LLM needed)
    fixed_sql = match_fixed_query(query_text)
    if fixed_sql:
        log_timing("fixed_match", time.time() - start_time, f"matched: {query_text[:60]}")
        memory.add_user(query_text)
        response = _execute_fixed_query_sql(query_text, fixed_sql, start_time, memory)
        memory.add_ai(response.content)
        _cache_query_response(query_text, response)
        return response

    # CHECK 2: Is this a disambiguation response?
    if memory.has_pending_disambiguation():
        pending = memory.get_pending_disambiguation()
        original_query = pending["original_query"]
        ambiguous_term = pending["ambiguous_term"]
        selected_column = query_text  # User selected column

        # Combine: "total quantity for plant CP01" + "Requested Quantity"
        # -> "total Requested Quantity for plant CP01"
        enhanced_query = combine_query_with_disambiguation(
            original_query, ambiguous_term, selected_column
        )
        print(f"[SQL Agent] Disambiguation resolved: '{original_query}' + '{selected_column}' -> '{enhanced_query}'")

        memory.clear_pending_disambiguation()
        memory.add_user(enhanced_query)

        # Generate SQL with enhanced query
        response = _execute_generated_query(enhanced_query, history, start_time, memory)
        memory.add_ai(response.content)
        return response

    # CHECK 3: Does query have ambiguous columns?
    disambiguation = detect_sql_disambiguation(query_text)

    if disambiguation:
        # Store pending disambiguation
        memory.set_pending_disambiguation({
            "original_query": query_text,
            "ambiguous_term": disambiguation["ambiguous_term"]
        })

        elapsed_time = round(time.time() - start_time, 2)

        # Create disambiguation options
        options = [
            DisambiguationOption(
                value=opt["value"],
                display=opt["display"],
                description=opt.get("description", "")
            )
            for opt in disambiguation["options"]
        ]

        return SQLAgentResponse(
            content=disambiguation["question"],
            response_time=f"{elapsed_time}s",
            sources=["Waybills DB"],
            needs_disambiguation=True,
            disambiguation_options=options
        )

    # Normal flow: add message to history
    memory.add_user(query_text)

    # Generate SQL with LLM (flexible path, pass history and memory for context)
    response = _execute_generated_query(query_text, history, start_time, memory)
    memory.add_ai(response.content)
    _cache_query_response(query_text, response)
    return response


def _execute_fixed_query_sql(query_text: str, sql_query: str, start_time: float, memory) -> SQLAgentResponse:
    """Execute a predefined fixed query with given SQL."""
    # Check cache first
    t0 = time.time()
    cached = _get_cached_result(sql_query)
    if cached:
        log_timing("sql_exec", time.time() - t0, "CACHE HIT")
        result = cached
    else:
        result = execute_sql(DB_PATH, sql_query)
        log_timing("sql_exec", time.time() - t0, "fixed query")
        if "error" not in result:
            _set_cached_result(sql_query, result)

    elapsed_time = round(time.time() - start_time, 2)

    if "error" in result:
        return SQLAgentResponse(
            content=f'**Error executing query:**\n\n`{result["error"]}`',
            response_time=f"{elapsed_time}s",
            sources=["Waybills DB"],
            sql_query=sql_query
        )

    # Store result context for follow-up queries
    context = _extract_result_context(result)
    if context:
        memory.set_last_result_context(context)

    # Check for scalar result (template, no LLM)
    if is_scalar_result(result):
        scalar_value = result["rows"][0][0]
        column_name = result["columns"][0]
        natural_response = generate_scalar_response(query_text, column_name, scalar_value)
        return SQLAgentResponse(
            content=natural_response,
            response_time=f"{elapsed_time}s",
            sources=["Waybills DB"],
            sql_query=sql_query
        )

    # Table result (template, no LLM)
    row_count = len(result["rows"])
    summary = generate_table_summary(query_text, result["columns"], row_count)

    # Detect visualization
    visualization = detect_visualization(result["columns"], result["rows"], query_text)

    return SQLAgentResponse(
        content=summary,
        response_time=f"{elapsed_time}s",
        sources=["Waybills DB"],
        table_data=TableData(columns=result["columns"], rows=result["rows"]),
        sql_query=sql_query,
        visualization=visualization
    )


def _execute_generated_query(query_text: str, history: str, start_time: float, memory) -> SQLAgentResponse:
    """Generate SQL with LLM (with timeout) and execute (with caching)."""
    try:
        # Get context summary from previous result for follow-up references
        context_summary = memory.get_context_summary()

        # Build prompt with conversation context for follow-up questions
        if history or context_summary:
            prompt_text = f"""Conversation History:
{history}

{context_summary}

Current Question: {query_text}

IMPORTANT: Use the conversation history AND the previous result context to understand references like "this vendor", "that contractor", "same plant", "this route", etc. Extract the actual values from the context above."""
        else:
            prompt_text = query_text

        # Generate SQL using LLM (with 30s timeout protection)
        system_msg = SystemMessage(content=system_prompt)
        human_msg = HumanMessage(content=prompt_text)

        t0 = time.time()
        response = invoke_with_timeout([system_msg, human_msg], timeout=120)
        log_timing("sql_gen", time.time() - t0, "LLM SQL generation")

        raw_content = response.content
        data = json.loads(raw_content)
        sql_query = data["sql"]
        print(f"[SQL Agent] Generated: {sql_query}")

        # Check if LLM returned unsupported request
        if sql_query.startswith("UNSUPPORTED_REQUEST:"):
            elapsed_time = round(time.time() - start_time, 2)
            message = sql_query.replace("UNSUPPORTED_REQUEST:", "").strip()
            return SQLAgentResponse(
                content=f"**Notice:** {message}",
                response_time=f"{elapsed_time}s",
                sources=["AI Assistant"]
            )

        # Execute the SQL query (check cache first)
        t0 = time.time()
        cached = _get_cached_result(sql_query)
        if cached:
            result = cached
            log_timing("sql_exec", time.time() - t0, "CACHE HIT")
        else:
            result = execute_sql(DB_PATH, sql_query)
            log_timing("sql_exec", time.time() - t0, "DB query")
            if "error" not in result:
                _set_cached_result(sql_query, result)

        elapsed_time = round(time.time() - start_time, 2)
        log_timing("total", elapsed_time, f"query: {query_text[:60]}")

        if "error" in result:
            return SQLAgentResponse(
                content=f'**Error executing query:**\n\n`{result["error"]}`\n\n**Generated SQL:**\n```sql\n{sql_query}\n```',
                response_time=f"{elapsed_time}s",
                sources=["Waybills DB"],
                sql_query=sql_query
            )

        # Store result context for follow-up queries
        context = _extract_result_context(result)
        if context:
            memory.set_last_result_context(context)

        # Check for scalar result (template, no LLM)
        if is_scalar_result(result):
            scalar_value = result["rows"][0][0]
            column_name = result["columns"][0]
            natural_response = generate_scalar_response(query_text, column_name, scalar_value)
            return SQLAgentResponse(
                content=natural_response,
                response_time=f"{elapsed_time}s",
                sources=["Waybills DB"],
                sql_query=sql_query
            )

        # Table result (template, no LLM)
        row_count = len(result["rows"])
        summary = generate_table_summary(query_text, result["columns"], row_count)

        # Detect visualization
        visualization = detect_visualization(result["columns"], result["rows"], query_text)

        return SQLAgentResponse(
            content=summary,
            response_time=f"{elapsed_time}s",
            sources=["Waybills DB"],
            table_data=TableData(columns=result["columns"], rows=result["rows"]),
            sql_query=sql_query,
            visualization=visualization
        )

    except TimeoutError as e:
        elapsed_time = round(time.time() - start_time, 2)
        log_timing("sql_gen", elapsed_time, "TIMEOUT")
        return SQLAgentResponse(
            content=f'**Error:** LLM timed out after 120 seconds. Please try a simpler query.',
            response_time=f"{elapsed_time}s",
            sources=["System"]
        )
    except json.JSONDecodeError as e:
        elapsed_time = round(time.time() - start_time, 2)
        return SQLAgentResponse(
            content=f'**Error:** Failed to parse LLM response as JSON.\n\n{str(e)}',
            response_time=f"{elapsed_time}s",
            sources=["LLM"]
        )
    except Exception as e:
        elapsed_time = round(time.time() - start_time, 2)
        return SQLAgentResponse(
            content=f'**Error:** {str(e)}',
            response_time=f"{elapsed_time}s",
            sources=["System"]
        )
