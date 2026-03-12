# Fleet Dispatch AI Assistant

An AI-powered dispatch management assistant for fuel logistics operations. Users query waybill, contractor, vendor, and route data using natural language (English & Arabic). Results are returned as interactive tables with summaries, or direct natural language responses.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **1.2.0** | 2026-03-12 | Corporate security: RBAC, token refresh, MFA (TOTP), data retention, column encryption |
| 1.1.0 | 2026-03-09 | Security layer: JWT auth, input validation, rate limiting, audit logging |
| 1.0.1 | 2026-02-25 | Performance: keyword router, template summaries, query caching, fixed queries |
| 1.0.0 | 2026-02-20 | Initial release: LLM SQL agent, chat UI, Flutter mobile app |

## Features

### Core
- Natural language queries (English & Arabic)
- SQL generation via local LLM (Ollama `gpt-oss`)
- Scalar results as natural language, tabular results with summaries
- CSV download, pagination, real-time streaming responses
- PDF document intelligence (RAG-based)
- Category-based quick queries with fuzzy matching

### Security (v1.2.0)
- **JWT Authentication** — access tokens (8h) + refresh tokens (7d)
- **RBAC** — role-based access control (admin, operations, finance, viewer, user)
- **MFA (TOTP)** — two-factor authentication via Google Authenticator / any TOTP app
- **Data Retention** — automatic cleanup of audit logs (30d) and caches (1h)
- **Column Encryption** — sensitive data encrypted at rest in server cache
- **Rate Limiting** — per-user request throttling
- **Input Validation** — SQL injection prevention, query sanitization
- **Audit Logging** — all API requests logged with user, IP, timestamp

### Platforms
- **Web App** — React + Tailwind CSS (served from FastAPI in production)
- **Mobile App** — Flutter (Android APK, iOS ready)

## Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Python | 3.11+ | Backend API server |
| Node.js | 18+ | Frontend build (development only) |
| Ollama | Latest | Local LLM inference |
| Flutter | 3.x | Mobile app build (optional) |

## Quick Start

### 1. Install Ollama & Pull Model

```bash
# Install Ollama (https://ollama.ai)
ollama pull gpt-oss
```

### 2. Install Dependencies

```bash
# Frontend
npm install

# Backend
pip install -r backend/requirements.txt
```

### 3. Start the Application

```bash
# Terminal 1: Ollama (if not running as service)
ollama serve

# Terminal 2: Backend API
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 3: Frontend dev server (development only)
npm run dev
```

| Service | URL | Notes |
|---------|-----|-------|
| Backend API | http://localhost:8000 | Also serves built web app |
| Frontend Dev | http://localhost:5173 | Hot-reload, proxies to :8000 |
| API Docs | http://localhost:8000/docs | Swagger UI |

### 4. Build for Production

```bash
# Web frontend
npm run build    # outputs to dist/

# Flutter APK
cd fleet_dispatch_app
flutter build apk --release --dart-define=ENV=local
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## Test Accounts

| Username | Password | Role |
|----------|----------|------|
| pb | admin1234 | admin |
| user1 | user1pass | user |
| user2 | user2pass | user |
| user3 | user3pass | user |
| user4 | user4pass | user |

> `users.json` is auto-generated on first run and excluded from version control.

## API Endpoints

### Authentication
| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/login` | POST | No | Login (returns JWT + refresh token) |
| `/api/token/refresh` | POST | No | Exchange refresh token for new access token |
| `/api/mfa/login` | POST | No | Complete MFA login with TOTP code |

### MFA Management
| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/mfa/status` | POST | Yes | Check if MFA is enabled for current user |
| `/api/mfa/setup` | POST | Yes | Generate TOTP secret + QR code |
| `/api/mfa/verify` | POST | Yes | Verify TOTP code to enable MFA |
| `/api/mfa/disable` | POST | Yes | Disable MFA (requires password + TOTP) |

### Queries
| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/query` | POST | Yes | Process natural language query |
| `/api/query/stream` | POST | Yes | Streaming query response (SSE) |
| `/api/route` | POST | Yes | Route query to category (without executing) |
| `/api/results/{id}` | GET | Yes | Paginated cached results |

### Data & Admin
| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/categories` | GET | No | Query categories |
| `/api/categories/{id}/queries` | GET | No | Sample queries per category |
| `/api/ai-overview` | GET | No | AI assistant overview |
| `/api/usage-stats` | GET | No | Usage statistics |
| `/api/admin/cleanup` | POST | Admin | Manual data retention cleanup |

## Project Structure

```
chatbot_mobileapp/
├── backend/
│   ├── main.py                 # FastAPI app, all API endpoints
│   ├── auth.py                 # JWT (access/refresh/MFA tokens)
│   ├── rbac.py                 # Role-based access control
│   ├── mfa.py                  # TOTP MFA (pyotp + QR codes)
│   ├── encryption.py           # Column-level encryption
│   ├── data_retention.py       # Scheduled cleanup of logs/caches
│   ├── router.py               # Query routing (keyword-based)
│   ├── utils.py                # LLM model, SQL execution
│   ├── fixed_queries.py        # Pre-defined SQL patterns
│   ├── langgraph_workflow.py   # LangGraph orchestration
│   ├── audit_log.py            # Request audit logging middleware
│   ├── agents/
│   │   └── sql_agent.py        # SQL generation agent with caching
│   ├── pdf_agent/              # PDF RAG intelligence
│   ├── requirements.txt        # Python dependencies
│   └── static/                 # APK download page
├── components/
│   ├── ChatWidget.tsx          # Chat interface with streaming
│   ├── MfaSetup.tsx            # MFA setup/disable modal
│   ├── LiveDemoTab.tsx         # Live query demo tab
│   ├── ValueAddedTab.tsx       # Value proposition cards
│   ├── ErrorBoundary.tsx       # React error boundary
│   ├── InfoPanel.tsx           # AI overview panel
│   └── UsageStats.tsx          # Statistics display
├── fleet_dispatch_app/           # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── services/
│   │   │   └── auth_service.dart    # Auth + MFA + token refresh
│   │   ├── providers/
│   │   │   └── auth_provider.dart   # Riverpod auth state
│   │   └── core/network/
│   │       └── api_client.dart      # Dio HTTP client + auto-refresh
│   └── android/                     # Android build config
├── App.tsx                     # Main React app (login + MFA + routing)
├── apiClient.ts                # Fetch wrapper with auto token refresh
├── all_waybills.db             # SQLite database (~20K records)
├── SECURITY_ROADMAP.md         # Security implementation tracker
├── README_DEPLOYMENT.md        # Server deployment guide
└── README.md                   # This file
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | (dev fallback) | JWT signing secret — **must set in production** |
| `DATA_ENCRYPTION_KEY` | (dev fallback) | Column encryption key — **must set in production** |
| `CORS_ORIGINS` | `*` | Allowed CORS origins (comma-separated) |
| `VITE_API_URL` | (empty) | Frontend API base URL override |

## RBAC Roles

| Role | SQL | CSV | PDF | Math | Greeting |
|------|-----|-----|-----|------|----------|
| admin | Yes | Yes | Yes | Yes | Yes |
| operations | Yes | Yes | No | Yes | Yes |
| finance | Yes | No | No | Yes | Yes |
| viewer | No | No | No | No | Yes |
| user | Yes | Yes | No | Yes | Yes |

## Architecture

```
                    ┌─────────────────┐
  Android APK ──────┤                 │
                    │   FastAPI       │        ┌──────────┐
  Web Browser ──────┤   (port 8000)   ├────────┤  Ollama  │
                    │                 │        │ gpt-oss  │
  curl / API  ──────┤   JWT + RBAC   │        └──────────┘
                    │   MFA (TOTP)    │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │   SQLite DB     │
                    │  all_waybills   │
                    └─────────────────┘
```

## Sample Queries

- "Show today's dispatch details"
- "How many waybills are there?"
- "List waybills for VENDOR-A"
- "Show contractor-wise summary"
- "What is the status of waybill 2-25-0010405?"
- "Monthly fuel consumption summary"

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| Backend | FastAPI, LangChain, LangGraph, Ollama, SQLite, PyOTP |
| Web Frontend | React 19, TypeScript, Vite, Tailwind CSS |
| Mobile App | Flutter 3, Dart, Riverpod, Dio |
| Security | JWT (PyJWT), PBKDF2-SHA256, TOTP (RFC 6238), XOR column encryption |
