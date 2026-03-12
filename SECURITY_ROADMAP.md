# Fleet Dispatch — Security Roadmap
**Version:** v1.2.0
**Date:** 2026-03-11
**Status:** Phase 1, 2, and 4 (5 of 10 items) Complete

---

## Progress Overview

```
Phase 1: Backend Security ........................ DONE (v1.0.0)
Phase 2: Frontend + Mobile Auth .................. DONE (v1.1.0)
Phase 3: Infrastructure (deployment team) ........ PENDING
Phase 4: Corporate Security ...................... 5/10 DONE (v1.2.0)
```

---

## PHASE 1 — Mandatory for App Store Launch

> Without these, the app WILL BE REJECTED by the stores or violate their policies.

| # | Security Item | Status | Notes |
|---|--------------|--------|-------|
| 1.1 | **HTTPS (SSL/TLS)** | PENDING | Deployment team — SSL cert + Nginx reverse proxy |
| 1.2 | **Privacy Policy URL** | PENDING | Legal team — public URL required for store submission |
| 1.3 | **Data Safety Declaration (Google Play)** | PENDING | Fill during Google Play submission |
| 1.4 | **App Privacy Details (Apple)** | PENDING | Fill during Apple App Store submission |
| 1.5 | **JWT Authentication** | DONE (v1.0.0) | `backend/auth.py` — PBKDF2-SHA256 hashed passwords, JWT tokens |
| 1.6 | **Input Validation** | DONE (v1.0.0) | `backend/input_validator.py` — SQL injection + XSS + length limits |

---

## PHASE 2 — Recommended for Launch (Professional Quality)

> Not strictly required by stores, but expected for a professional/customer-facing app.

| # | Security Item | Status | Notes |
|---|--------------|--------|-------|
| 2.1 | **Password Hashing (PBKDF2-SHA256)** | DONE (v1.0.0) | `backend/auth.py` — salted PBKDF2-SHA256, 100K iterations |
| 2.2 | **CORS Tightening** | DONE (v1.0.0) | `backend/main.py` — restricted to known origins |
| 2.3 | **Rate Limiting** | DONE (v1.0.0) | `backend/rate_limiter.py` — 60 req/min per user |
| 2.4 | **Audit Logging** | DONE (v1.0.0) | `backend/audit_log.py` — user, endpoint, status, duration |
| 2.5 | **401 Handling (Auto-logout)** | DONE (v1.1.0) | Web: `apiClient.ts`, Flutter: `api_client.dart` |

---

## PHASE 3 — Infrastructure (Deployment Team)

> Required before app store submission. Not code changes — IT/deployment/legal team tasks.

| # | Item | Owner | Status |
|---|------|-------|--------|
| 3.1 | **SSL Certificate** | Deployment team | PENDING — Let's Encrypt or company CA |
| 3.2 | **Reverse Proxy (Nginx/Caddy)** | Deployment team | PENDING — HTTPS termination in front of uvicorn |
| 3.3 | **Environment Variables** | Deployment team | PENDING — Set `JWT_SECRET`, `CORS_ORIGINS`, `DATA_ENCRYPTION_KEY` on server |
| 3.4 | **Privacy Policy URL** | Legal team | PENDING — Draft and host at a public URL |
| 3.5 | **Store Submission** | Dev + Legal | PENDING — After 3.1–3.4 are done |

---

## PHASE 4 — Corporate Security (Post-Launch)

> Enterprise-grade features. 5 of 10 items completed in v1.2.0.

### DONE

| # | Security Item | What Was Built | Files |
|---|--------------|----------------|-------|
| 4.1 | **Role-Based Access Control (RBAC)** | 5 roles (`admin`, `operations`, `finance`, `viewer`, `user`) mapped to allowed query categories. Permission checked before every query. Role included in JWT and login response. | `backend/rbac.py` (new), `backend/auth.py`, `backend/main.py` |
| 4.2 | **Token Refresh** | 7-day refresh tokens issued on login. Auto-refresh on 401 in web (`apiClient.ts`) and Flutter (`api_client.dart`). New endpoint `POST /api/token/refresh`. | `backend/auth.py`, `backend/main.py`, `apiClient.ts`, `api_client.dart` |
| 4.3 | **Data Retention Policy** | Background scheduler: audit logs auto-deleted after 30 days, caches cleaned every 1 hour. Admin can trigger manual cleanup via `POST /api/admin/cleanup`. | `backend/data_retention.py` (new), `backend/main.py` |
| 4.4 | **Multi-Factor Authentication (MFA)** | TOTP via authenticator apps (Google Authenticator, Microsoft Authenticator, etc.). Setup with QR code, 6-digit code verification. Login flow: password → MFA challenge → full JWT. Endpoints: `/api/mfa/setup`, `/api/mfa/verify`, `/api/mfa/disable`, `/api/mfa/login`. | `backend/mfa.py` (new), `backend/auth.py`, `backend/main.py`, `App.tsx`, `auth_service.dart`, `auth_provider.dart` |
| 4.5 | **Column-Level Encryption** | Sensitive columns (Contractor Name, Vendor Name, quantities, driver_id) encrypted with XOR+base64 before caching. Protects data at rest in server-side caches. | `backend/encryption.py` (new), `backend/main.py` |

### REMAINING (FUTURE)

| # | Security Item | Description | Effort | Priority |
|---|--------------|-------------|--------|----------|
| 4.6 | **SSO / Active Directory** | Replace username/password with SAML/OAuth2/Azure AD single sign-on. Allows IT to manage user access centrally. | High | When moving to enterprise |
| 4.7 | **End-to-End Encryption** | Encrypt chat messages between app and server beyond HTTPS. Required for highly sensitive data. | Medium | When handling classified data |
| 4.8 | **API Gateway / WAF** | Web Application Firewall (AWS WAF, Cloudflare) for DDoS protection, bot detection, IP blocking. | Medium | When deploying to cloud |
| 4.9 | **Penetration Testing** | Hire professional security firm to test: login bypass, data access, server crashes, injection attacks. Delivers report with findings. | External | Before enterprise rollout |
| 4.10 | **OWASP Compliance Audit** | Full OWASP Top 10 security review of backend and mobile app. | External | Before enterprise rollout |

---

## New Endpoints (v1.2.0)

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/token/refresh` | POST | No (refresh token is the credential) | Exchange refresh token for new access token |
| `/api/mfa/setup` | POST | Bearer token | Generate TOTP secret + QR code for authenticator app |
| `/api/mfa/verify` | POST | Bearer token | Verify TOTP code during setup (enables MFA) |
| `/api/mfa/disable` | POST | Bearer token | Disable MFA (requires password + TOTP code) |
| `/api/mfa/login` | POST | No (MFA pending token) | Complete MFA login with 6-digit TOTP code |
| `/api/admin/cleanup` | POST | Bearer token (admin only) | Trigger manual cleanup of audit logs + caches |

---

## Files Added/Modified in v1.2.0

### New Files (3)

| File | Purpose |
|------|---------|
| `backend/rbac.py` | Role → permission mappings, `check_permission()` |
| `backend/data_retention.py` | Scheduled cleanup of audit logs (30d) and caches (1h) |
| `backend/mfa.py` | TOTP: secret generation, QR codes, code verification (pyotp + qrcode) |
| `backend/encryption.py` | Column-level XOR encryption for sensitive data in caches |

### Modified Files (8)

| File | Changes |
|------|---------|
| `backend/auth.py` | Refresh tokens (7d), MFA-pending tokens (5min), role in JWT, `save_users()` |
| `backend/main.py` | RBAC checks, 6 new endpoints, encryption on results, retention scheduler |
| `backend/users.json` | Added `mfa_secret`, `mfa_enabled` fields |
| `backend/requirements.txt` | Added `pyotp==2.9.0`, `qrcode[pil]==8.0` |
| `apiClient.ts` | Refresh token storage, auto-refresh on 401, role storage |
| `App.tsx` | MFA 6-digit code entry screen, stores refresh token + role |
| `auth_service.dart` | `loginMfa()`, refresh/role storage, updated `loginRemote()` |
| `api_client.dart` | `_refreshToken()`, auto-refresh on 401 with request retry |
| `auth_provider.dart` | `mfaRequired` status, `verifyMfa()`, role in state |

---

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `JWT_SECRET` | Secret key for signing JWT tokens | Production |
| `CORS_ORIGINS` | Comma-separated allowed origins | Production |
| `DATA_ENCRYPTION_KEY` | Key for column-level encryption | Production |

---

## Implementation History

```
v1.0.0 (2026-03-03) — Phase 1: Backend Security
  DONE  auth.py + users.json (JWT + PBKDF2-SHA256)
  DONE  input_validator.py (SQL injection, XSS, length)
  DONE  rate_limiter.py (60 req/min per user)
  DONE  audit_log.py (request logging)
  DONE  main.py (auth guards, CORS tightening)

v1.1.0 (2026-03-10) — Phase 2: Frontend + Mobile Auth
  DONE  apiClient.ts (web auth wrapper)
  DONE  App.tsx, ChatWidget.tsx (web login/logout)
  DONE  auth_service.dart, api_client.dart (Flutter JWT + 401)

v1.2.0 (2026-03-11) — Phase 4: Corporate Security (5 features)
  DONE  RBAC (rbac.py — 5 roles, per-route permission checks)
  DONE  Token Refresh (7-day refresh tokens, auto-refresh on 401)
  DONE  Data Retention (30-day audit log cleanup, hourly cache cleanup)
  DONE  MFA/TOTP (pyotp, QR setup, 6-digit login flow)
  DONE  Column-Level Encryption (sensitive columns encrypted in caches)

--- PENDING ---

Phase 3: Infrastructure (deployment team)
  TODO  SSL certificate + HTTPS
  TODO  Privacy policy URL
  TODO  Store submission forms

Phase 4: Remaining Corporate Security
  TODO  SSO / Active Directory integration
  TODO  End-to-End Encryption
  TODO  API Gateway / WAF
  TODO  Penetration Testing
  TODO  OWASP Compliance Audit
```

---

## Notes for Manager

- **Phases 1, 2, and 4 (partial)** are code changes — completed by dev team
- **Phase 3** requires IT/deployment team and legal team — **blocking for store submission**
- **Phase 4 remaining** (SSO, E2E encryption, WAF, pen testing) is post-launch, planned for enterprise rollout
- The app has **6 layers of security**: JWT auth, input validation, rate limiting, audit logging, RBAC, and MFA
- Mobile app has additional **PIN lock + biometric auth** (local) and **encrypted storage** (AES via flutter_secure_storage)
- After Phase 3 completion, the app meets **Google Play and Apple App Store security requirements**
