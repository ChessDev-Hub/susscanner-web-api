#Requires -Version 7.0
<#
.SYNOPSIS
  Initialize a repo, optionally create it on GitHub, push, and open a PR.

.EXAMPLE
  .\Check-in\Setup-And-CheckIn.ps1 `
    -Org "ChessDev-Hub" `
    -Repo "sus-scanner-api" `
    -Private `
    -InitGit `
    -CreateRepo `
    -CommitMessage "api: initial FastAPI scaffold" `
    -OpenPR `
    -Reviewers "ChessDev-Hub/dev1","ChessDev-Hub/dev2"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Org,
  [Parameter(Mandatory)][string]$Repo,

  [switch]$Private,
  [switch]$InitGit,
  [switch]$CreateRepo,

  [string]$BaseBranch = "main",
  [string]$FeatureBranch,

  [string]$CommitMessage = "chore: initial commit",

  [switch]$OpenPR,
  [string[]]$Reviewers = @(),

  # Optional branch protection for base branch
  [switch]$RequireCI,
  [string[]]$RequiredChecks = @()
)

# Relaunch under PS7 if someone starts it with Windows PowerShell by accident
if ($PSVersionTable.PSEdition -ne 'Core') {
  Write-Host "Re-launching under PowerShell 7..." -ForegroundColor Yellow
  & pwsh -ExecutionPolicy Bypass -File $PSCommandPath @args
  exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Error $Message
  exit 1
}

function Exec {
  param(
    [Parameter(Mandatory)][string]$File,
    [string[]]$Args = @(),
    [string]$ErrorMessage = "Command failed: $File $($Args -join ' ')"
  )
  Write-Host ">> $File $($Args -join ' ')" -ForegroundColor DarkGray
  & $File @Args
  if ($LASTEXITCODE -ne 0) { Fail $ErrorMessage }
}

# Validate tooling
try { Exec -File 'git' -Args @('--version') -ErrorMessage 'git is not available in PATH.' } catch { throw }
try { Exec -File 'gh' -Args @('--version') -ErrorMessage 'GitHub CLI (gh) is not available in PATH.' } catch { throw }

# Prepare values
$repoSlug   = "$Org/$Repo"
$visibility = if ($Private.IsPresent) { 'private' } else { 'public' }
if (-not $FeatureBranch) {
  $safeRepo = ($Repo -replace '[^\w\-\.]', '-')
  $FeatureBranch = "feat/$safeRepo-initial"
}

# Remove Zone.Identifier if present (non-fatal)
try { Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue } catch {}

# --- Git init & first commit --------------------------------------------------
if ($InitGit) {
  if (-not (Test-Path -Path '.git')) {
    Exec -File 'git' -Args @('init') -ErrorMessage 'git init failed'
  }

  # Ensure base branch exists locally
  Exec -File 'git' -Args @('checkout', '-B', $BaseBranch) -ErrorMessage "git checkout -B $BaseBranch failed"

  # Basic .gitignore if none exists (optional)
  if (-not (Test-Path '.gitignore')) {
    @(
      '# OS / Editor',
      '.DS_Store',
      '*.code-workspace',
      '.vscode/',
      '# Python',
      '__pycache__/',
      '*.pyc',
      '.venv/',
      '# Node',
      'node_modules/'
    ) | Set-Content -Path '.gitignore' -Encoding UTF8
  }

  # Stage & commit
  Exec -File 'git' -Args @('add', '--all') -ErrorMessage 'git add failed'
  # Commit only if there’s something to commit
  $status = & git status --porcelain
  if ($status) {
    Exec -File 'git' -Args @('commit', '-m', $CommitMessage) -ErrorMessage 'git commit failed'
  } else {
    Write-Host "No changes to commit on $BaseBranch." -ForegroundColor Yellow
  }
}

# --- Create the GitHub repo (if requested) -----------------------------------
if ($CreateRepo) {
  $exists = $false
  try {
    & gh repo view $repoSlug 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) { $exists = $true }
  } catch { $exists = $false }

  if (-not $exists) {
    $visFlag = if ($visibility -eq 'private') { '--private' } else { '--public' }
    # NOTE: gh warns --confirm is deprecated; passing -y (global yes) suppresses prompts.
    Exec -File 'gh' -Args @('-y','repo','create', $repoSlug, $visFlag) -ErrorMessage "gh repo create $repoSlug failed"
  } else {
    Write-Host "Repo $repoSlug already exists on GitHub." -ForegroundColor Yellow
  }
}

# --- Configure origin & push base branch -------------------------------------
$originUrl = "https://github.com/$repoSlug.git"
$remotes = & git remote 2>$null
if ($LASTEXITCODE -ne 0) { $remotes = @() }

if ($remotes -match '^origin$') {
  Exec -File 'git' -Args @('remote', 'set-url', 'origin', $originUrl) -ErrorMessage 'Failed to update remote origin'
} else {
  Exec -File 'git' -Args @('remote', 'add', 'origin', $originUrl) -ErrorMessage 'Failed to add remote origin'
}

# Ensure base branch exists locally
Exec -File 'git' -Args @('checkout', $BaseBranch) -ErrorMessage "git checkout $BaseBranch failed"

# Create upstream branch and push
Exec -File 'git' -Args @('push', '-u', 'origin', $BaseBranch) -ErrorMessage "git push origin $BaseBranch failed"

# --- Optional: create feature branch, push, and open PR ----------------------
if ($OpenPR) {
  # Create/update feature branch from base
  Exec -File 'git' -Args @('checkout', '-B', $FeatureBranch, $BaseBranch) -ErrorMessage "git checkout -B $FeatureBranch failed"
  Exec -File 'git' -Args @('push', '-u', 'origin', $FeatureBranch) -ErrorMessage "git push origin $FeatureBranch failed"

  # Ensure feature branch is ahead of base. If not, add an empty commit to enable PR creation.
  $counts = (& git rev-list --left-right --count "$BaseBranch...$FeatureBranch").Trim()
  if (-not $counts) { $counts = "0 0" }
  $onlyFeature = [int]($counts -split '\s+')[1]
  if ($onlyFeature -eq 0) {
    Write-Host "Feature branch has no commits ahead of $BaseBranch; adding empty commit so PR can be created..." -ForegroundColor Yellow
    & git commit --allow-empty -m "chore: scaffold PR (empty diff)"
    if ($LASTEXITCODE -ne 0) { Fail "Failed to create empty commit" }
    & git push
    if ($LASTEXITCODE -ne 0) { Fail "Failed to push empty commit" }
  }

  # Create PR
  $prTitle = "Initialize $Repo"
  $prBody  = @"
Automated scaffold for **$Repo**.

- Base branch: `$BaseBranch`
- Feature branch: `$FeatureBranch`

Generated by Setup-And-CheckIn.ps1.
"@
  $prArgs = @(
    '-y', 'pr','create',
    '--base', $BaseBranch,
    '--head', $FeatureBranch,
    '--title', $prTitle,
    '--body',  $prBody
  )
  Exec -File 'gh' -Args $prArgs -ErrorMessage 'gh pr create failed'

  if ($Reviewers.Count -gt 0) {
    $editArgs = @('-y','pr','edit','--add-reviewer') + $Reviewers
    Exec -File 'gh' -Args $editArgs -ErrorMessage 'gh pr edit (add reviewers) failed'
  }
}

# --- Optional: protect base branch & require CI checks -----------------------
if ($RequireCI) {
  if ($RequiredChecks.Count -eq 0) { $RequiredChecks = @('ci') }

  $protection = @{
    required_status_checks = @{
      strict   = $true
      contexts = $RequiredChecks
    }
    enforce_admins = $true
    restrictions   = $null
    required_pull_request_reviews = @{
      required_approving_review_count = 1
      dismiss_stale_reviews           = $true
      require_code_owner_reviews      = $false
    }
    allow_force_pushes     = $false
    allow_deletions        = $false
    block_creations        = $false
    required_linear_history = $false
    lock_branch            = $false
    allow_fork_syncing     = $true
  }

  $tmp = New-TemporaryFile
  try {
    $protection | ConvertTo-Json -Depth 10 | Set-Content -Path $tmp -Encoding UTF8

    Exec -File 'gh' -Args @(
      'api',
      '--method','PUT',
      '--header','Accept: application/vnd.github+json',
      "/repos/$Org/$Repo/branches/$BaseBranch/protection",
      '--input', $tmp
    ) -ErrorMessage "gh api to set branch protection on $BaseBranch failed"
  }
  finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
  }
}

Write-Host ""
Write-Host "✅ Done." -ForegroundColor Green
Write-Host "Repo: https://github.com/$repoSlug" -ForegroundColor Green
if ($OpenPR) {
  try {
    $prUrl = (& gh pr view --json url --jq '.url')
    if ($LASTEXITCODE -eq 0 -and $prUrl) {
      Write-Host "PR:   $prUrl" -ForegroundColor Green
    }
  } catch {}
}
