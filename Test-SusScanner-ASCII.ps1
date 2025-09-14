<# 
.SYNOPSIS
  ASCII-only smoke test for the Sus Scanner API (avoids Unicode issues).

.EXAMPLES
  # Test Render deployment
  .\Test-SusScanner-ASCII.ps1 -BaseUrl https://sus-scanner-api.onrender.com -Username alalper

  # Test local dev on port 8000
  .\Test-SusScanner-ASCII.ps1 -BaseUrl http://127.0.0.1:8000 -Username testuser

  # Include a CORS preflight test (simulate browser)
  .\Test-SusScanner-ASCII.ps1 -BaseUrl https://sus-scanner-api.onrender.com -Username alalper -FrontendOrigin https://chessdev-hub.github.io
#>

param(
  [string]$BaseUrl = "https://sus-scanner-api.onrender.com",
  [string]$Username = "alalper",
  [int]$TimeoutSec = 20,
  [string]$FrontendOrigin = ""   # e.g., https://chessdev-hub.github.io
)

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[X] $msg" -ForegroundColor Red }

function Get-Url([string]$path) {
  $base = $BaseUrl.TrimEnd("/")
  $p = $path.TrimStart("/")
  return "$base/$p"
}

function Measure-Request([scriptblock]$block) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $result = & $block
  $sw.Stop()
  return @{ Result = $result; Ms = $sw.Elapsed.TotalMilliseconds }
}

Write-Info "PowerShell $($PSVersionTable.PSVersion) on $([System.Environment]::OSVersion.Platform)"
Write-Info "BaseUrl = $BaseUrl"
Write-Info "Username = $Username"
if ($FrontendOrigin) { Write-Info "FrontendOrigin = $FrontendOrigin (will run a CORS preflight)" }

# DNS check
try {
  $uri = [uri]$BaseUrl
  if ($uri.Host) {
    Write-Info "Resolving DNS for $($uri.Host)..."
    try {
      $dns = Resolve-DnsName -Name $uri.Host -ErrorAction Stop
      $ips = ($dns | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique) -join ", "
      Write-Ok "Resolved $($uri.Host) -> $ips"
    } catch {
      Write-Warn "DNS resolve failed for $($uri.Host): $($_.Exception.Message)"
    }
  }
} catch {
  Write-Err "Invalid BaseUrl: $BaseUrl"
  exit 2
}

# 1) GET /health
$healthUrl = Get-Url "/health"
Write-Info "GET $healthUrl"
try {
  $h = Measure-Request { Invoke-WebRequest -Uri $healthUrl -Method GET -TimeoutSec $TimeoutSec -UseBasicParsing }
  Write-Ok ("Health OK (HTTP {0}) in {1:N0} ms" -f $h.Result.StatusCode, $h.Ms)
  try {
    $json = $h.Result.Content | ConvertFrom-Json
    if ($json.ok -ne $true) { Write-Warn "Response JSON does not contain ok:true" }
  } catch {
    Write-Warn ("Health response is not valid JSON: {0}" -f $_.Exception.Message)
  }
} catch {
  Write-Err ("Health check FAILED: {0}" -f $_.Exception.Message)
  Write-Host "  Hints:" -ForegroundColor DarkGray
  Write-Host "   - If this is Render: ensure it's a Web Service (not Static Site)." -ForegroundColor DarkGray
  Write-Host "   - Start command must be: uvicorn api.main:app --host 0.0.0.0 --port $PORT" -ForegroundColor DarkGray
  Write-Host "   - Check Render 'Health Check Path' is /health and logs for boot errors." -ForegroundColor DarkGray
}

# 2) (Optional) CORS preflight OPTIONS /scan
if ($FrontendOrigin) {
  $scanUrl = Get-Url "/scan"
  Write-Info "OPTIONS (CORS preflight) $scanUrl (Origin: $FrontendOrigin)"
  try {
    $pre = Measure-Request { 
      Invoke-WebRequest -Uri $scanUrl -Method OPTIONS -TimeoutSec $TimeoutSec -UseBasicParsing -Headers @{
        "Origin" = $FrontendOrigin
        "Access-Control-Request-Method" = "POST"
        "Access-Control-Request-Headers" = "content-type"
      }
    }
    Write-Ok ("CORS preflight responded (HTTP {0}) in {1:N0} ms" -f $pre.Result.StatusCode, $pre.Ms)
    $allowOrigin = $pre.Result.Headers["access-control-allow-origin"]
    $allowMeth   = $pre.Result.Headers["access-control-allow-methods"]
    $allowHdr    = $pre.Result.Headers["access-control-allow-headers"]
    if (-not $allowOrigin) { Write-Warn "No 'access-control-allow-origin' header in response." }
    else { Write-Info ("access-control-allow-origin: {0}" -f $allowOrigin) }
    if ($allowMeth) { Write-Info ("access-control-allow-methods: {0}" -f $allowMeth) }
    if ($allowHdr)  { Write-Info ("access-control-allow-headers: {0}" -f $allowHdr)  }
  } catch {
    Write-Warn ("CORS preflight FAILED or not implemented by server: {0}" -f $_.Exception.Message)
    Write-Host "  Tip: FastAPI + CORSMiddleware usually handles OPTIONS automatically." -ForegroundColor DarkGray
    Write-Host "       Ensure CORS_ORIGINS includes the frontend origin exactly." -ForegroundColor DarkGray
  }
}

# 3) POST /scan
$scanUrl = Get-Url "/scan"
Write-Info "POST $scanUrl"
$body = @{ username = $Username } | ConvertTo-Json
try {
  $s = Measure-Request {
    Invoke-WebRequest -Uri $scanUrl -Method POST -TimeoutSec $TimeoutSec -UseBasicParsing `
      -Headers @{ "Content-Type" = "application/json" } -Body $body
  }
  Write-Ok ("Scan request OK (HTTP {0}) in {1:N0} ms" -f $s.Result.StatusCode, $s.Ms)
  try {
    $json = $s.Result.Content | ConvertFrom-Json
    Write-Info "Response (pretty):"
    $json | ConvertTo-Json -Depth 10 | Out-String | Write-Host
  } catch {
    Write-Warn ("Scan response is not valid JSON: {0}" -f $_.Exception.Message)
    Write-Host $s.Result.Content
  }
} catch {
  Write-Err ("Scan request FAILED: {0}" -f $_.Exception.Message)
  Write-Host "  Common causes:" -ForegroundColor DarkGray
  Write-Host "   - Static Site instead of Web Service on host" -ForegroundColor DarkGray
  Write-Host "   - Wrong start command or module path" -ForegroundColor DarkGray
  Write-Host "   - scanner.py missing or import error" -ForegroundColor DarkGray
  Write-Host "   - SusScanner constructor kwargs mismatch" -ForegroundColor DarkGray
  Write-Host "   - analyze_user / analyze_player not defined" -ForegroundColor DarkGray
}

Write-Host ""
Write-Ok "Done."
