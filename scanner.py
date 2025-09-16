# scanner.py (repo root)
from typing import Dict, Any
import os

def analyze_player(username: str) -> Dict[str, Any]:
    # avoid any interactive prompts in containers
    os.environ.setdefault("USER_EMAIL", "allenalper@me.com")
    # TODO: replace with your real logic
    return {"username": username, "suspicion_score": 0.0, "reasons": []}
