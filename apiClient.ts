/**
 * Authenticated API client for Fleet Dispatch web frontend.
 * Wraps fetch() to add JWT Bearer token to all requests.
 */

import { API_BASE_URL } from './constants';

const TOKEN_KEY = 'authToken';

export function getToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  sessionStorage.setItem(TOKEN_KEY, token);
}

export function clearAuth(): void {
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem('loggedIn');
  sessionStorage.removeItem('username');
}

function handleUnauthorized(): void {
  clearAuth();
  window.location.reload();
}

/**
 * Authenticated fetch wrapper. Adds Authorization header and handles 401.
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

  if (response.status === 401 && !path.includes('/api/login')) {
    handleUnauthorized();
    throw new Error('Session expired. Please login again.');
  }

  return response;
}
