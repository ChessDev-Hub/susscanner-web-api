
import os, importlib
from typing import Any, Dict
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

origins_env = os.getenv("CORS_ORIGINS", "")
origins = [o.strip() for o in origins_env.split(",") if o.strip()] or [
    "http://localhost:3000","http://127.0.0.1:3000",
    "http://localhost:5173","http://127.0.0.1:5173",
]

app = FastAPI(title="Sus Scanner API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health() -> Dict[str, bool]:
    return {"ok": True}

_ScannerCls = None
_analyze_fn = None
_loaded = False

def _load_scanner_once() -> None:
    global _ScannerCls, _analyze_fn, _loaded
    if _loaded: return
    try:
        mod = importlib.import_module("scanner")
        _ScannerCls = getattr(mod, "SusScanner", None)
        _analyze_fn = (
            getattr(mod, "analyze_user", None)
            or getattr(mod, "analyze_player", None)
        )
    except Exception:
        pass
    _loaded = True

class ScanRequest(BaseModel):
    username: str

def _to_json(obj: Any) -> Dict[str, Any]:
    if isinstance(obj, dict): return obj
    if hasattr(obj, "model_dump"): return obj.model_dump()
    if hasattr(obj, "__dict__"):
        return {k: v for k, v in vars(obj).items() if not k.startswith("_")}
    return {"result": str(obj)}

@app.post("/scan")
def scan(req: ScanRequest) -> Dict[str, Any]:
    username = (req.username or "").strip()
    if not username:
        raise HTTPException(400, "username is required")

    ua_email = os.getenv("USER_EMAIL")
    if ua_email: os.environ["USER_EMAIL"] = ua_email

    _load_scanner_once()

    if _analyze_fn is not None:
        try:
            metrics = _analyze_fn(username)
        except Exception as e:
            raise HTTPException(500, f"analyze function failed: {e}")
        return _to_json(metrics)

    if _ScannerCls is not None:
        try:
            scanner = _ScannerCls(lookback_months=3, wr_gap_suspect=0.25)
            if hasattr(scanner, "analyze_user"):
                metrics = scanner.analyze_user(username)
            elif hasattr(scanner, "analyze_player"):
                metrics = scanner.analyze_player(username)
            else:
                raise HTTPException(500, "scanner lacks analyze_user/analyze_player")
        except Exception as e:
            raise HTTPException(500, f"scanner failed: {e}")
        return _to_json(metrics)

    raise HTTPException(
        500,
        "scanner.py not loaded: define class `SusScanner` (.analyze_user) or "
        "export `analyze_user(name)` / `analyze_player(name)`."
    )

