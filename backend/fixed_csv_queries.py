"""
Fixed CSV query patterns for vehicle dwell time data.
Executes pandas operations directly on the DataFrame — no LLM needed.

Columns: vehicle_name, driver_id, zone_name, month, entry_time, exit_time, dwell_hrs, dwell_minutes
"""

import re
import pandas as pd
from typing import Optional, Tuple


def match_fixed_csv_query(query: str, df: pd.DataFrame) -> Optional[Tuple[pd.DataFrame, str, str]]:
    """
    Match a query against fixed CSV patterns and execute directly on DataFrame.

    Args:
        query: User's natural language query
        df: The vehicle dwell time DataFrame

    Returns:
        Tuple of (result_df_or_scalar, summary_text, pandas_code) if matched, None otherwise.
    """
    q = query.lower().strip()

    # --- Average dwell time by zone ---
    if _matches(q, ["average", "dwell", "zone"]) or _matches(q, ["avg", "dwell", "zone"]) or _matches(q, ["mean", "dwell", "zone"]):
        code = "result = df.groupby('zone_name')['dwell_hrs'].mean().sort_values(ascending=False).round(2)"
        result = df.groupby('zone_name')['dwell_hrs'].mean().sort_values(ascending=False).round(2)
        return result, "Average dwell time (hours) by zone", code

    # --- Average dwell time by driver ---
    if _matches(q, ["average", "dwell", "driver"]) or _matches(q, ["avg", "dwell", "driver"]):
        code = "result = df.groupby('driver_id')['dwell_hrs'].mean().sort_values(ascending=False).round(2)"
        result = df.groupby('driver_id')['dwell_hrs'].mean().sort_values(ascending=False).round(2)
        return result, "Average dwell time (hours) by driver", code

    # --- Total dwell time by zone ---
    if _matches(q, ["total", "dwell", "zone"]) or _matches(q, ["sum", "dwell", "zone"]):
        code = "result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).round(2)"
        result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).round(2)
        return result, "Total dwell time (hours) by zone", code

    # --- Total dwell time by driver ---
    if _matches(q, ["total", "dwell", "driver"]) or _matches(q, ["sum", "dwell", "driver"]):
        code = "result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).round(2)"
        result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).round(2)
        return result, "Total dwell time (hours) by driver", code

    # --- Top N drivers by dwell time ---
    top_n_match = re.search(r'top\s+(\d+)\s+driver', q)
    if top_n_match and any(kw in q for kw in ["dwell", "time", "hour", "duration", "stay"]):
        n = int(top_n_match.group(1))
        code = f"result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).head({n}).round(2)"
        result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).head(n).round(2)
        return result, f"Top {n} drivers by total dwell hours", code

    # --- Top N zones by dwell time ---
    top_n_match = re.search(r'top\s+(\d+)\s+zone', q)
    if top_n_match and any(kw in q for kw in ["dwell", "time", "hour", "duration", "stay"]):
        n = int(top_n_match.group(1))
        code = f"result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).head({n}).round(2)"
        result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).head(n).round(2)
        return result, f"Top {n} zones by total dwell hours", code

    # --- Trip count per zone ---
    if _matches(q, ["trip", "count", "zone"]) or _matches(q, ["visit", "count", "zone"]) or _matches(q, ["trip", "per", "zone"]) or _matches(q, ["how", "many", "trip", "zone"]):
        code = "result = df.groupby('zone_name').size().sort_values(ascending=False).rename('trip_count')"
        result = df.groupby('zone_name').size().sort_values(ascending=False).rename('trip_count')
        return result, "Trip count per zone", code

    # --- Trip count per driver ---
    if _matches(q, ["trip", "count", "driver"]) or _matches(q, ["visit", "count", "driver"]) or _matches(q, ["trip", "per", "driver"]) or _matches(q, ["how", "many", "trip", "driver"]):
        code = "result = df.groupby('driver_id').size().sort_values(ascending=False).rename('trip_count')"
        result = df.groupby('driver_id').size().sort_values(ascending=False).rename('trip_count')
        return result, "Trip count per driver", code

    # --- Trip count per vehicle ---
    if _matches(q, ["trip", "count", "vehicle"]) or _matches(q, ["trip", "per", "vehicle"]) or _matches(q, ["how", "many", "trip", "vehicle"]):
        code = "result = df.groupby('vehicle_name').size().sort_values(ascending=False).rename('trip_count')"
        result = df.groupby('vehicle_name').size().sort_values(ascending=False).rename('trip_count')
        return result, "Trip count per vehicle", code

    # --- Longest dwell times ---
    top_n_longest = re.search(r'(?:top|longest|highest)\s+(\d+)?\s*(?:dwell|stay|duration)', q)
    if top_n_longest or _matches(q, ["longest", "dwell"]) or _matches(q, ["highest", "dwell"]) or _matches(q, ["maximum", "dwell"]):
        n = int(top_n_longest.group(1)) if top_n_longest and top_n_longest.group(1) else 10
        code = f"result = df.nlargest({n}, 'dwell_hrs')[['vehicle_name', 'driver_id', 'zone_name', 'dwell_hrs', 'entry_time', 'exit_time']]"
        result = df.nlargest(n, 'dwell_hrs')[['vehicle_name', 'driver_id', 'zone_name', 'dwell_hrs', 'entry_time', 'exit_time']]
        return result, f"Top {n} longest dwell times", code

    # --- Shortest dwell times ---
    if _matches(q, ["shortest", "dwell"]) or _matches(q, ["lowest", "dwell"]) or _matches(q, ["minimum", "dwell"]):
        code = "result = df.nsmallest(10, 'dwell_hrs')[['vehicle_name', 'driver_id', 'zone_name', 'dwell_hrs', 'entry_time', 'exit_time']]"
        result = df.nsmallest(10, 'dwell_hrs')[['vehicle_name', 'driver_id', 'zone_name', 'dwell_hrs', 'entry_time', 'exit_time']]
        return result, "Top 10 shortest dwell times", code

    # --- Summary statistics ---
    if _matches(q, ["summary", "statistic"]) or _matches(q, ["dwell", "summary"]) or _matches(q, ["describe", "dwell"]) or _matches(q, ["overview", "dwell"]):
        stats = df['dwell_hrs'].describe().round(2)
        result = pd.DataFrame({'statistic': stats.index, 'value': stats.values})
        code = "result = df['dwell_hrs'].describe().round(2)"
        return result, "Dwell time (hours) summary statistics", code

    # --- Total trips / total records ---
    if _matches(q, ["total", "trip"]) or _matches(q, ["how", "many", "record"]) or _matches(q, ["total", "record"]) or _matches(q, ["how", "many", "entries"]):
        count = len(df)
        return count, f"Total records in the dataset: **{count:,}**", "result = len(df)"

    # --- List all zones ---
    if _matches(q, ["list", "zone"]) or _matches(q, ["all", "zone"]) or _matches(q, ["show", "zone"]):
        code = "result = df['zone_name'].unique()"
        zones = df['zone_name'].unique()
        result = pd.DataFrame({'zone_name': sorted(zones)})
        return result, f"All zones ({len(zones)} total)", code

    # --- List all drivers ---
    if _matches(q, ["list", "driver"]) or _matches(q, ["all", "driver"]) or _matches(q, ["show", "driver"]):
        code = "result = df['driver_id'].unique()"
        drivers = df['driver_id'].unique()
        result = pd.DataFrame({'driver_id': sorted(drivers)})
        return result, f"All drivers ({len(drivers)} total)", code

    # --- List all vehicles ---
    if _matches(q, ["list", "vehicle"]) or _matches(q, ["all", "vehicle"]) or _matches(q, ["show", "vehicle"]):
        code = "result = df['vehicle_name'].unique()"
        vehicles = df['vehicle_name'].unique()
        result = pd.DataFrame({'vehicle_name': sorted(vehicles)})
        return result, f"All vehicles ({len(vehicles)} total)", code

    # --- Dwell time by month ---
    if _matches(q, ["dwell", "month"]) or _matches(q, ["dwell", "monthly"]):
        code = "result = df.groupby('month')['dwell_hrs'].sum().sort_index().round(2)"
        result = df.groupby('month')['dwell_hrs'].sum().sort_index().round(2)
        return result, "Total dwell time (hours) by month", code

    # --- Trips by month ---
    if _matches(q, ["trip", "month"]) or _matches(q, ["trips", "monthly"]) or _matches(q, ["visits", "month"]):
        code = "result = df.groupby('month').size().sort_index().rename('trip_count')"
        result = df.groupby('month').size().sort_index().rename('trip_count')
        return result, "Trip count by month", code

    # --- Top N drivers (general, no dwell keyword) ---
    top_n_match = re.search(r'top\s+(\d+)\s+driver', q)
    if top_n_match:
        n = int(top_n_match.group(1))
        code = f"result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).head({n}).round(2)"
        result = df.groupby('driver_id')['dwell_hrs'].sum().sort_values(ascending=False).head(n).round(2)
        return result, f"Top {n} drivers by total dwell hours", code

    # --- Top N zones (general, no dwell keyword) ---
    top_n_match = re.search(r'top\s+(\d+)\s+zone', q)
    if top_n_match:
        n = int(top_n_match.group(1))
        code = f"result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).head({n}).round(2)"
        result = df.groupby('zone_name')['dwell_hrs'].sum().sort_values(ascending=False).head(n).round(2)
        return result, f"Top {n} zones by total dwell hours", code

    return None


def _matches(text: str, keywords: list) -> bool:
    """Check if ALL keywords appear in the text (as substrings)."""
    return all(kw in text for kw in keywords)
