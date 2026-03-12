/**
 * Authenticated API client for Fleet Dispatch web frontend.
 * Wraps fetch() to add JWT Bearer token to all requests.
 * Supports token refresh on 401 and MFA flow.
 */

import { API_BASE_URL } from './constants';

const TOKEN_KEY = 'authToken';
const REFRESH_TOKEN_KEY = 'refreshToken';
const ROLE_KEY = 'userRole';

let _isRefreshing = false;
let _refreshPromise: Promise<boolean> | null = null;

export function getToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  sessionStorage.setItem(TOKEN_KEY, token);
}

export function getRefreshToken(): string | null {
  return sessionStorage.getItem(REFRESH_TOKEN_KEY);
}

export function setRefreshToken(token: string): void {
  sessionStorage.setItem(REFRESH_TOKEN_KEY, token);
}

export function getUserRole(): string | null {
  return sessionStorage.getItem(ROLE_KEY);
}

export function setUserRole(role: string): void {
  sessionStorage.setItem(ROLE_KEY, role);
}

export function clearAuth(): void {
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(REFRESH_TOKEN_KEY);
  sessionStorage.removeItem(ROLE_KEY);
  sessionStorage.removeItem('loggedIn');
  sessionStorage.removeItem('username');
}

function handleUnauthorized(): void {
  clearAuth();
  window.location.reload();
}

/**
 * Attempt to refresh the access token using the stored refresh token.
 * Returns true if refresh succeeded, false otherwise.
 */
async function tryRefreshToken(): Promise<boolean> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return false;

  try {
    const res = await fetch(`${API_BASE_URL}/api/token/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });

    if (res.ok) {
      const data = await res.json();
      setToken(data.access_token);
      if (data.refresh_token) setRefreshToken(data.refresh_token);
      if (data.role) setUserRole(data.role);
      return true;
    }
  } catch {
    // Refresh failed
  }
  return false;
}

/**
 * Authenticated fetch wrapper. Adds Authorization header and handles 401.
 * On 401: tries token refresh before logging out.
 */
export async function apiFetch(
  path: string,
  options: RequestInit = {}
): Promise<Response> {
  const token = getToken();
  const headers: Record<string, string> = {
    'ngrok-skip-browser-warning': 'true',
    ...(options.headers as Record<string, string> || {}),
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  if (response.status === 401 && !path.includes('/api/login') && !path.includes('/api/token/refresh')) {
    // Try to refresh token before giving up
    if (!_isRefreshing) {
      _isRefreshing = true;
      _refreshPromise = tryRefreshToken().finally(() => {
        _isRefreshing = false;
        _refreshPromise = null;
      });
    }

    const refreshed = await (_refreshPromise || tryRefreshToken());
    if (refreshed) {
      // Retry the original request with the new token
      const newToken = getToken();
      if (newToken) {
        headers['Authorization'] = `Bearer ${newToken}`;
      }
      return fetch(`${API_BASE_URL}${path}`, { ...options, headers });
    }

    // Refresh failed — logout
    handleUnauthorized();
    throw new Error('Session expired. Please login again.');
  }

  return response;
}
