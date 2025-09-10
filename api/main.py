# api/main.py
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

origins_env = os.getenv("CORS_ORIGINS", "")
origins = [o.strip() for o in origins_env.split(",") if o.strip()] or [
    "http://localhost:5173", "http://127.0.0.1:5173",
    "http://localhost:3000", "http://127.0.0.1:3000",
]

app = FastAPI(title="Sus Scanner API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"ok": True, "service": "Sus Scanner API"}

@app.get("/health")
def health():
    return {"ok": True}

class ScanRequest(BaseModel):
    username: str

def _to_json(obj):
    if isinstance(obj, dict): return obj
    if hasattr(obj, "model_dump"): return obj.model_dump()  # pydantic v2
    if hasattr(obj, "__dict__"):
        return {k: v for k, v in vars(obj).items() if not k.startswith("_")}
    return {"result": str(obj)}

@app.post("/scan")
def scan(req: ScanRequest):
    username = (req.username or "").strip()
    if not username:
        raise HTTPException(status_code=400, detail="username is required")

    # Lazy import so server still boots even if scanner.py isn’t present yet.
    SusScanner = None
    analyze_user_fn = None
    try:
        from scanner import SusScanner as _SusScanner   # type: ignore
        SusScanner = _SusScanner
    except Exception:
        try:
            from scanner import analyze_user as _analyze_user  # type: ignore
            analyze_user_fn = _analyze_user
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"scanner import failed: {e}")

    ua_email = os.getenv("USER_EMAIL")
    if ua_email: os.environ["USER_EMAIL"] = ua_email

    if analyze_user_fn:
        metrics = analyze_user_fn(username)
    else:
        scanner = SusScanner(lookback_months=3, wr_gap_suspect=0.25)
        if hasattr(scanner, "analyze_user"):
            metrics = scanner.analyze_user(username)
        elif hasattr(scanner, "analyze_player"):
            metrics = scanner.analyze_player(username)
        else:
            raise HTTPException(500, "scanner lacks analyze_user/analyze_player")

    return _to_json(metrics)
