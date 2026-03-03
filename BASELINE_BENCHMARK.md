# Baseline Response Time Benchmark
**Date:** 2026-02-24
**LLM Model:** gpt-oss:latest (via Ollama, local)
**Backend:** FastAPI + LangGraph + SQL Agent

## Results

| # | Query | Route Time | Query Time | Total (Client) | Backend Time | Route | Chart Type | Rows |
|---|-------|-----------|------------|----------------|--------------|-------|------------|------|
| 1 | Fuel type highest quantity | 320ms | 31,514ms | **31.8s** | 0.02s | sql | none (1 row) | 1 |
| 2 | Contractor waybill count | 13,711ms | 55,291ms | **69.0s** | 42.91s | sql | horizontal_bar | 47 |
| 3 | 47 contractors cancelled vs rejected | 17,810ms | 107,384ms | **125.2s** | 95.11s | sql | horizontal_grouped_bar | 47 |
| 4 | Waybills Delivered/Expired/Cancelled | 16,475ms | 11,447ms | **27.9s** | 0.01s | sql | none (1 row) | 1 |
| 5 | Vendor most rejected | 17,956ms | 31,928ms | **49.9s** | 0.01s | sql | none (1 row) | 1 |
| 6 | Monthly cancelled vs expired | 16,712ms | 70,195,592ms | **~70,212s** | 70,183.4s | sql | line | 8 |
| 7 | Contractor waybill list | 16,021ms | 11,759ms | **27.8s** | 0.05s | sql | none (table) | 100 |

## Summary Statistics

- **Average route classification time:** ~14.3s (LLM call via Ollama)
- **Fastest total response:** 27.8s (fixed/simple queries)
- **Slowest total response:** ~70,212s (query #6 - anomaly, likely LLM hung)
- **Typical complex query:** 50-125s

## Bottleneck Analysis

1. **Route classification (LLM call):** 14-18s per query — this alone is slow
2. **SQL generation (LLM call):** Additional 10-95s depending on complexity
3. **Table summary (LLM call):** Additional LLM overhead on table results
4. **Total LLM calls per query:** 2-3 calls

## Notes

- Query #1 was the first call (possibly model cold start, only 320ms for route)
- Query #6 had an anomalously long time (~70K seconds) — likely the LLM got stuck in a loop
- Backend "response_time" shows 0.01s for fixed/scalar queries (fast path works)
- All queries routed to "sql" agent
