# SENTINEL: SusScanner main.py v2 (lazy-load)

import os
import importlib
from typing import Any, Dict, Optional

from fastapi import FastAPI, APIRouter, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────

# Allow overriding with comma-separated env var:
#   CORS_ORIGINS="https://chessdev-hub.github.io, http://localhost:5173"
origins_env = os.getenv("CORS_ORIGINS", "")

# Default origins cover local dev AND your GitHub Pages site.
DEFAULT_ORIGINS = [
    "http://localhost:3000", "http://127.0.0.1:3000",
    "http://localhost:5173", "http://127.0.0.1:5173",
    "https://chessdev-hub.github.io",
]

origins = [o.strip() for o in origins_env.split(",") if o.strip()] or DEFAULT_ORIGINS

# Optional API prefix, e.g. "/api"
API_PREFIX = os.getenv("API_PREFIX", "").strip()  # "" or "/api"

# ──────────────────────────────────────────────────────────────────────────────
# App + CORS
# ──────────────────────────────────────────────────────────────────────────────

app = FastAPI(title="Sus Scanner API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

router = APIRouter()

@router.get("/health")
def health() -> Dict[str, bool]:
    return {"ok": True}

# Optional debug endpoint to see what's loaded and the prefix being used.
@router.get("/debug")
def debug() -> Dict[str, str]:
    return {
        "api_prefix": API_PREFIX or "",
        "loaded": str(_loaded),
        "has_analyze_fn": str(_analyze_fn is not None),
        "has_scanner_cls": str(_ScannerCls is not None),
        "file": __file__,
        "origins": ",".join(origins),
        "scanner_module": _scanner_modname or "",
    }

# ──────────────────────────────────────────────────────────────────────────────
# Lazy load scanner from multiple possible module paths
# ──────────────────────────────────────────────────────────────────────────────

_ScannerCls: Optional[type] = None
_analyze_fn = None
_loaded = False
_scanner_modname: Optional[str] = None

def _import_first(*module_names: str):
    last_err = None
    for name in module_names:
        try:
            mod = importlib.import_module(name)
            # print is fine for Render logs
            print(f"[sus-scanner] using scanner module: {name}")
            return name, mod
        except Exception as e:
            last_err = e
    if last_err:
        raise last_err
    raise ImportError("No module names provided")

def _load_scanner_once() -> None:
    """Load either a function analyze_user/analyze_player or a SusScanner class."""
    global _ScannerCls, _analyze_fn, _loaded, _scanner_modname
    if _loaded:
        return

    # Try several common locations
    # - "scanner"                  (single-file module)
    # - "services.scanner"         (monorepo/services layout)
    # - "api.scanner"              (some repos keep logic under api/)
    modname, mod = _import_first("scanner", "services.scanner", "api.scanner")
    _scanner_modname = modname

    _ScannerCls = getattr(mod, "SusScanner", None)
    # Prefer analyze_user, then analyze_player
    _analyze_fn = getattr(mod, "analyze_user", None) or getattr(mod, "analyze_player", None)

    _loaded = True

# ──────────────────────────────────────────────────────────────────────────────
# Models + helpers
# ──────────────────────────────────────────────────────────────────────────────

class ScanRequest(BaseModel):
    username: str

def _to_json(obj: Any) -> Dict[str, Any]:
    if isinstance(obj, dict):
        return obj
    if hasattr(obj, "model_dump"):
        return obj.model_dump()  # pydantic v2 models
    if hasattr(obj, "__dict__"):
        return {k: v for k, v in vars(obj).items() if not k.startswith("_")}
    return {"result": str(obj)}

# ──────────────────────────────────────────────────────────────────────────────
# Routes
# ──────────────────────────────────────────────────────────────────────────────

@router.post("/scan")
def scan(req: ScanRequest) -> Dict[str, Any]:
    username = (req.username or "").strip()
    if not username:
        raise HTTPException(400, "username is required")

    # Forward USER_EMAIL env if present (kept from your earlier code)
    ua_email = os.getenv("USER_EMAIL")
    if ua_email:
        os.environ["USER_EMAIL"] = ua_email

    try:
        _load_scanner_once()
    except Exception as e:
        raise HTTPException(500, f"failed to import scanner module: {e}")

    # 1) function-style API
    if _analyze_fn is not None:
        try:
            metrics = _analyze_fn(username)
        except Exception as e:
            raise HTTPException(500, f"analyze function failed: {e}")
        return _to_json(metrics)

    # 2) class-style API
    if _ScannerCls is not None:
        try:
            scanner = _ScannerCls(lookback_months=3, wr_gap_suspect=0.25)
            if hasattr(scanner, "analyze_user"):
                metrics = scanner.analyze_user(username)
            elif hasattr(scanner, "analyze_player"):
                metrics = scanner.analyze_player(username)
            else:
                raise HTTPException(500, "SusScanner lacks analyze_user/analyze_player")
        except Exception as e:
            raise HTTPException(500, f"scanner failed: {e}")
        return _to_json(metrics)

    raise HTTPException(
        500,
        "scanner module loaded but no entrypoints found. "
        "Define class `SusScanner` (.analyze_user/.analyze_player) or export "
        "`analyze_user(name)` / `analyze_player(name)`."
    )

# Mount router (with optional prefix)
app.include_router(router, prefix=API_PREFIX)
