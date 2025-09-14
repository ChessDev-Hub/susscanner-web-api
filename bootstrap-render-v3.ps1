<# 
Creates a minimal FastAPI app for Render and pushes it.
RUN THIS from the ROOT of the repo that's connected to Render (e.g., SusScannerWebApi).
#>

param(
  [switch] $SkipGitPush = $false,
  [int] $LocalPort = 8000
)

$ErrorActionPreference = "Stop"

function Write-File($Path, $Content) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -Path $Path -Value $Content -Encoding UTF8 -Force
  Write-Host "✔ Wrote $Path"
}

# 1) Files Render expects
$requirements = @'
fastapi
uvicorn[standard]
pydantic>=2
requests
'@

$dockerfile = @'
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["sh","-c","uvicorn api.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
'@

$main_py = @'
# api/main.py
from typing import Dict, Any
from fastapi import FastAPI
from pydantic import BaseModel
from scanner import analyze_player  # imports from /app/scanner.py

app = FastAPI(title="Sus Scanner API", version="0.1.0")

@app.get("/health")
def health() -> Dict[str, bool]:
    return {"ok": True}

class ScanRequest(BaseModel):
    username: str

@app.post("/scan")
def scan(req: ScanRequest) -> Dict[str, Any]:
    return analyze_player(req.username)
'@

$scanner_py = @'
# /scanner.py
from typing import Dict, Any
import os

# Replace this class with your real implementation later.
class SusScanner:
    def __init__(self, lookback_months: int = 2):
        self.lookback_months = lookback_months

    def analyze_user(self, username: str):
        # TODO: call your real logic here
        return {
            "username": username,
            "suspicion_score": 0.0,
            "reasons": [],
        }

def analyze_player(username: str) -> Dict[str, Any]:
    # Prevent interactive prompts in containers
    os.environ.setdefault("USER_EMAIL", "allenalper@me.com")

    scanner = SusScanner(lookback_months=2)
    m = scanner.analyze_user(username)
    # Ensure plain JSON (no custom objects)
    return {
        "username": m.get("username", username),
        "suspicion_score": float(m.get("suspicion_score", 0.0)),
        "reasons": list(m.get("reasons", [])),
    }
'@

# 2) Write files
Write-File -Path ".\requirements.txt" -Content $requirements
Write-File -Path ".\Dockerfile" -Content $dockerfile
Write-File -Path ".\api\main.py" -Content $main_py
Write-File -Path ".\scanner.py" -Content $scanner_py

# 3) Optional: quick local run helper (venv-free)
$runLocal = @'
# Quick local run (optional)
#   python -m pip install -r requirements.txt
#   python -m uvicorn api.main:app --reload --host 127.0.0.1 --port <<PORT>>
'@ -replace '<<PORT>>', $LocalPort

Write-File -Path ".\RUN-LOCAL.txt" -Content $runLocal

# 4) Git commit & push
if (-not $SkipGitPush) {
  try {
    git add -A
    git commit -m "feat: minimal FastAPI on Render (/health, /scan) + Dockerfile"
  } catch {
    Write-Host "(i) Nothing to commit or git not configured: $($_.Exception.Message)"
  }
  try {
    git push
    Write-Host "🚀 Pushed to remote. Render should auto-redeploy."
  } catch {
    Write-Host "⚠ Could not push. Make sure this repo has a remote and you're logged in (git)."
  }
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "1) Render will build and start your service automatically."
Write-Host "2) Test after deploy:"
Write-Host "   Invoke-RestMethod https://sus-scanner-api.onrender.com/health"
Write-Host "   $body = @{ username = 'alalper' } | ConvertTo-Json"
Write-Host "   Invoke-RestMethod -Uri https://sus-scanner-api.onrender.com/scan -Method Post -ContentType 'application/json' -Body $body"
Write-Host ""
Write-Host "Optional local test (same code):"
Write-Host ("   python -m pip install -r requirements.txt")
Write-Host ("   python -m uvicorn api.main:app --reload --host 127.0.0.1 --port {0}" -f $LocalPort)
