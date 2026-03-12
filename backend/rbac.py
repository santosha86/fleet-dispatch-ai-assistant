"""Role-Based Access Control (RBAC) for Fleet Dispatch API.

Defines role → allowed route categories mapping.
Checks user permissions before query processing.
"""

from fastapi import HTTPException, status

from .auth import load_users


# Role → allowed route categories
ROLE_PERMISSIONS = {
    "admin": ["sql", "csv", "pdf", "math", "greeting", "out_of_scope", "meta"],
    "operations": ["sql", "csv", "math", "greeting", "out_of_scope", "meta"],
    "finance": ["sql", "math", "greeting", "out_of_scope", "meta"],
    "viewer": ["greeting", "out_of_scope", "meta"],
    # "user" role maps to operations-level access (backward compat)
    "user": ["sql", "csv", "math", "greeting", "out_of_scope", "meta"],
}


def get_user_role(username: str) -> str:
    """Get the role for a given username from users.json."""
    users = load_users()
    user = users.get(username)
    if not user:
        return "viewer"  # safest default
    return user.get("role", "user")


def check_permission(username: str, route_category: str) -> None:
    """Check if user has permission to access the given route category.

    Args:
        username: The authenticated username.
        route_category: The query route category (sql, csv, pdf, math, etc.).

    Raises:
        HTTPException(403) if user lacks permission.
    """
    role = get_user_role(username)
    allowed = ROLE_PERMISSIONS.get(role, [])
    if route_category not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Your role '{role}' does not have permission to access {route_category} data.",
        )
