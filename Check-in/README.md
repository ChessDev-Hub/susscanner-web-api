# Sus Scanner API – Setup & Check-In

This repository contains automation scripts and scaffolding for the **Sus Scanner API** project.  
The included **PowerShell 7 script** (`Setup-And-CheckIn.ps1`) streamlines repository setup, GitHub initialization, branch protection, and pull request creation.

---

## 📦 Requirements

- **PowerShell 7.x (Core)**  
  Verify with:
  ```powershell
  $PSVersionTable.PSVersion
  ```
  Should show `7.x` and `PSEdition = Core`.

- **Git** installed and available in `PATH`.
- **GitHub CLI (gh)** installed and authenticated:
  ```powershell
  gh auth login
  ```

---

## ▶️ Usage

From the project root, run:

```powershell
.\Check-in\Setup-And-CheckIn.ps1 `
  -Org "ChessDev-Hub" `
  -Repo "sus-scanner-api" `
  -Private `
  -InitGit `
  -CreateRepo `
  -CommitMessage "api: initial FastAPI scaffold" `
  -OpenPR `
  -Reviewers "ChessDev-Hub/dev1","ChessDev-Hub/dev2"
```

### Common Parameters

| Parameter        | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `-Org`           | GitHub organization (e.g., `ChessDev-Hub`).                                |
| `-Repo`          | Repository name (e.g., `sus-scanner-api`).                                 |
| `-Private`       | Creates the repo as **private** (default is public).                       |
| `-InitGit`       | Initializes Git locally, adds `.gitignore`, commits files.                  |
| `-CreateRepo`    | Creates the repository on GitHub if it doesn’t exist.                      |
| `-CommitMessage` | Custom commit message for initial commit.                                  |
| `-OpenPR`        | Opens a pull request from feature branch into base branch.                 |
| `-Reviewers`     | List of GitHub reviewers (comma-separated).                                |
| `-BaseBranch`    | Base branch name (default: `main`).                                        |
| `-FeatureBranch` | Feature branch name (default: `feat/<repo>-initial`).                      |
| `-RequireCI`     | Enables branch protection with required CI checks.                         |
| `-RequiredChecks`| List of required GitHub status checks (default: `ci`).                     |

---

## 🚀 Quickstart for Contributors

1. **Clone the repository**  
   ```bash
   git clone https://github.com/ChessDev-Hub/sus-scanner-api.git
   cd sus-scanner-api
   ```

2. **Install prerequisites**  
   - Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
   - Install [Git](https://git-scm.com/downloads)
   - Install [GitHub CLI](https://cli.github.com/)

3. **Authenticate with GitHub CLI**  
   ```bash
   gh auth login
   ```

4. **Run the setup script** (to initialize repo, branches, PR, etc.)  
   ```powershell
   .\Check-in\Setup-And-CheckIn.ps1 -Org "ChessDev-Hub" -Repo "sus-scanner-api" -InitGit -OpenPR
   ```

5. **Start contributing!**  
   - Make changes in feature branches  
   - Push changes and open PRs via `gh` or the script  

---

## 🔒 Branch Protection Example

Require CI checks to pass before merging:

```powershell
.\Check-in\Setup-And-CheckIn.ps1 `
  -Org "ChessDev-Hub" `
  -Repo "sus-scanner-api" `
  -BaseBranch "main" `
  -RequireCI `
  -RequiredChecks "build","test"
```
.\Check-in\Setup-And-CheckIn.ps1 `
  -Org "ChessDev-Hub" `
  -Repo "sus-scanner-api" `
  -Private `
  -InitGit `
  -CreateRepo `
  -CommitMessage "api: initial FastAPI scaffold" `
  -OpenPR `
  -Reviewers "ChessDev-Hub/dev1","ChessDev-Hub/dev2"

---

## 📝 Notes

- If you see an error about **digitally signed scripts**, run once:
  ```powershell
  Unblock-File .\Check-in\Setup-And-CheckIn.ps1
  ```
- Or run with:
  ```powershell
  pwsh -ExecutionPolicy Bypass -File .\Check-in\Setup-And-CheckIn.ps1 ...
  ```
- Add `#Requires -Version 7.0` ensures it won’t run under Windows PowerShell 5.1.

---

## ✅ Outputs

- Local Git repo initialized (if requested).  
- GitHub repo created (if requested).  
- Base branch pushed to origin.  
- Optional PR created with reviewers added.  
- Optional branch protection configured.

---

## 🔗 Links

- [PowerShell Documentation](https://learn.microsoft.com/powershell/)  
- [GitHub CLI Docs](https://cli.github.com/manual/)  
- [Execution Policies](https://go.microsoft.com/fwlink/?LinkID=135170)  

---
