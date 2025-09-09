import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ---- CORS (dev defaults; tighten later via CORS_ORIGINS env)
origins_env = os.getenv("CORS_ORIGINS", "")
origins = [o.strip() for o in origins_env.split(",") if o.strip()] or [
    "http://localhost:3000", "http://127.0.0.1:3000",
    "http://localhost:5173", "http://127.0.0.1:5173",
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
def health():
    return {"ok": True}

# ---------- adapt to scanner.py shape ----------
SusScanner = None
analyze_user_fn = None
try:
    from scanner import SusScanner as _SusScanner  # class version
    SusScanner = _SusScanner
except Exception:
    pass
if analyze_user_fn is None:
    try:
        from scanner import analyze_user as _analyze_user  # function version
        analyze_user_fn = _analyze_user
    except Exception:
        pass
if SusScanner is None and analyze_user_fn is None:
    raise ImportError(
        "scanner.py must define class `SusScanner` (with .analyze_user(name)) "
        "or export function `analyze_user(name)`."
    )

class ScanRequest(BaseModel):
    username: str

def _to_json(obj):
    if isinstance(obj, dict):
        return obj
    if hasattr(obj, "model_dump"):
        return obj.model_dump()
    if hasattr(obj, "__dict__"):
        return {k: v for k, v in vars(obj).items() if not k.startswith("_")}
    return {"result": str(obj)}

@app.post("/scan")
def scan(req: ScanRequest):
    username = req.username.strip()
    if not username:
        raise HTTPException(status_code=400, detail="username is required")

    # some scanners want USER_EMAIL for User-Agent
    ua_email = os.getenv("USER_EMAIL")
    if ua_email:
        os.environ["USER_EMAIL"] = ua_email

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

# Optional tiny debug to see Origin
@app.get("/debug/origin")
def debug_origin(req: Request):
    return {"origin": req.headers.get("origin"), "referer": req.headers.get("referer")}
#@ | Set-Content -Encoding UTF8 .\api\main.py
