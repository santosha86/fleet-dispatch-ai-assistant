# Fleet Dispatch — Security Roadmap
**Version:** v1.1.0 (Security Layer Added)
**Date:** 2026-03-10
**Status:** Phase 1 & 2 Complete — Preparing for App Store Launch

---

## Priority Classification

### PRIORITY 1 — Mandatory for App Store Launch (Google Play + Apple App Store)
> Without these, the app WILL BE REJECTED by the stores or violate their policies.

| # | Security Item | Why Mandatory | Status |
|---|--------------|---------------|--------|
| 1.1 | **HTTPS (SSL/TLS)** | Both Google Play and Apple **require** all network traffic over HTTPS. Apple enforces App Transport Security (ATS) — HTTP calls are blocked by default on iOS. Google Play flags apps using cleartext HTTP. | PENDING (Deployment team) |
| 1.2 | **Privacy Policy URL** | Both stores **require** a public privacy policy URL during submission. Must describe what data is collected, how it's used, and how it's stored. | PENDING (Legal team) |
| 1.3 | **Data Safety Declaration (Google Play)** | Google Play requires a Data Safety form declaring what data the app collects/shares. | PENDING (During submission) |
| 1.4 | **App Privacy Details (Apple)** | Apple requires privacy nutrition labels — what data types are collected and linked to user identity. | PENDING (During submission) |
| 1.5 | **JWT Authentication** | Store reviewers test if the app handles auth properly. Login must return a real token, and API calls must be authenticated. Hardcoded passwords in source code is a rejection risk. | DONE |
| 1.6 | **Input Validation** | Both stores check for basic security — SQL injection, XSS, and oversized inputs must be handled. | DONE |

### PRIORITY 2 — Recommended for Launch (Professional Quality)
> Not strictly required by stores, but expected for a professional app shown to customers.

| # | Security Item | Why Recommended | Status |
|---|--------------|-----------------|--------|
| 2.1 | **Password Hashing (PBKDF2-SHA256)** | Plaintext passwords in code is a security red flag. Any security audit will flag this immediately. | DONE |
| 2.2 | **CORS Tightening** | Currently allows ALL origins (`*`). Should restrict to known domains to prevent cross-site attacks. | DONE |
| 2.3 | **Rate Limiting** | Prevents API abuse and protects the LLM from overload. Basic protection expected in any production API. | DONE |
| 2.4 | **Audit Logging** | Records who accessed what and when. Required for any customer-facing POC to demonstrate accountability. | DONE |
| 2.5 | **401 Handling (Auto-logout)** | When token expires, app should gracefully redirect to login instead of showing errors. | DONE |

### PRIORITY 3 — Corporate Security (Post-Launch)
> These are enterprise-grade features. Implement after successful store launch when scaling to production.

| # | Security Item | Description | Status |
|---|--------------|-------------|--------|
| 3.1 | **SSO / Active Directory Integration** | Replace username/password with company single sign-on (SAML, OAuth2, Azure AD). Allows IT to manage user access centrally. | FUTURE |
| 3.2 | **Role-Based Access Control (RBAC)** | Different permissions per role. Example: `admin` = full access, `operations` = dispatch/waybills/routes only, `finance` = finance queries only, `viewer` = read-only. Foundation already exists — `users.json` has a `role` field. Need to: (a) define roles & allowed query categories, (b) map router categories to roles, (c) check permissions before processing query. | FUTURE |
| 3.3 | **Token Refresh (Refresh Tokens)** | Instead of 8-hour tokens expiring and requiring re-login, use refresh tokens for seamless experience. | FUTURE |
| 3.4 | **Database Encryption** | Encrypt the SQLite database at rest. Currently unencrypted on server. | FUTURE |
| 3.5 | **End-to-End Encryption** | Encrypt chat messages between app and server (beyond HTTPS). Required for highly sensitive data. | FUTURE |
| 3.6 | **API Gateway / WAF** | Web Application Firewall (AWS WAF, Cloudflare) for DDoS protection, bot detection, IP blocking. | FUTURE |
| 3.7 | **Penetration Testing** | Professional security audit by a third-party firm before enterprise rollout. | FUTURE |
| 3.8 | **OWASP Compliance Audit** | Full OWASP Top 10 security review of backend and mobile app. | FUTURE |
| 3.9 | **Data Retention Policy** | Auto-delete chat history, audit logs after N days. Comply with company data governance. | FUTURE |
| 3.10 | **Multi-Factor Authentication (MFA)** | Add OTP/authenticator app as second factor. PIN/biometric in app is local only — not true MFA. | FUTURE |

---

## What We Build NOW (Priority 1 + 2)

### Backend Changes

| File | Change |
|------|--------|
| **NEW** `backend/auth.py` | JWT token creation, bcrypt password verification, FastAPI auth dependency |
| **NEW** `backend/users.json` | Bcrypt-hashed user credentials (auto-generated from current users) |
| **NEW** `backend/input_validator.py` | Query length limit (500 chars) + SQL injection pattern detection |
| **NEW** `backend/rate_limiter.py` | In-memory per-user rate limiting (60 req/min) |
| **NEW** `backend/audit_log.py` | Request logging: timestamp, user, endpoint, status, duration |
| **MODIFY** `backend/requirements.txt` | Add PyJWT, passlib[bcrypt] |
| **MODIFY** `backend/main.py` | JWT login, auth guards on all endpoints, CORS tightening, middleware |

### Web Frontend Changes

| File | Change |
|------|--------|
| **NEW** `apiClient.ts` | Authenticated fetch wrapper (adds Bearer token to all API calls) |
| **MODIFY** `App.tsx` | Store JWT on login, clear on logout |
| **MODIFY** `components/ChatWidget.tsx` | Use authenticated fetch (7 API calls) |
| **MODIFY** `components/UsageStats.tsx` | Use authenticated fetch (1 API call) |
| **MODIFY** `components/InfoPanel.tsx` | Use authenticated fetch (1 API call) |

### Flutter Mobile App Changes

| File | Change |
|------|--------|
| **MODIFY** `lib/services/auth_service.dart` | Remote login via backend API, JWT token storage |
| **MODIFY** `lib/core/network/api_client.dart` | Auth interceptor (adds Bearer token), 401 auto-logout |
| **MODIFY** `lib/providers/auth_provider.dart` | Use remote login instead of local validation |

### Infrastructure (Deployment Team)

| Item | Action Required |
|------|----------------|
| **SSL Certificate** | Obtain SSL cert (Let's Encrypt or company CA) and configure on server |
| **Reverse Proxy** | Set up Nginx/Caddy in front of uvicorn for HTTPS termination |
| **Environment Variables** | Set `JWT_SECRET` (random 32+ char string) and `CORS_ORIGINS` on server |
| **Privacy Policy** | Legal team drafts and hosts at a public URL |

---

## Implementation Order

```
Phase 1: Backend Security (we build now)
  ├── auth.py + users.json (JWT + bcrypt)
  ├── input_validator.py
  ├── rate_limiter.py
  ├── audit_log.py
  └── main.py updates (wire everything together)

Phase 2: Frontend + Mobile Auth (we build now)
  ├── apiClient.ts (web)
  ├── App.tsx, ChatWidget.tsx, etc. (web)
  └── auth_service.dart, api_client.dart (Flutter)

Phase 3: Infrastructure (deployment team)
  ├── SSL certificate + HTTPS
  ├── Privacy policy URL
  └── Store submission

Phase 4: Corporate Security (future)
  ├── SSO / Active Directory
  ├── RBAC, MFA, encryption
  └── Penetration testing
```

---

## Notes for Manager

- **Phases 1 & 2** are code changes — we handle this
- **Phase 3** requires IT/deployment team and legal team
- **Phase 4** is post-launch, planned for when the app moves from POC to production
- The app already has **PIN lock + biometric auth** on mobile (local security)
- The app already has **encrypted local storage** (flutter_secure_storage uses AES)
- After Phases 1-3, the app meets **Google Play and Apple App Store security requirements**
