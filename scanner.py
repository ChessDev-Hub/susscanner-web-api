from typing import Dict, Any

def analyze_player(username: str) -> Dict[str, Any]:
    """
    Minimal placeholder analysis. Replace with your real logic.
    Import path expected by FastAPI: `from scanner import analyze_player`
    """
    if not isinstance(username, str) or not username.strip():
        raise ValueError("username must be a non-empty string")

    # Example payload; expand with your real checks
    return {
        "username": username.strip(),
        "status": "ok",
        "suspicion_score": 0.0,
        "checks": {
            "account_age_days": None,
            "recent_timeouts": 0,
            "engine_match_rate": None,
        },
        "notes": "placeholder analysis; replace with real scanner logic",
    }
