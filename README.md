# SusScanner API (FastAPI)

Render-friendly backend for the SusScanner React UI.

## Endpoints
- `GET /health` — status check
- `GET /analyze/{username}` — analyze one player
- `POST /analyze-batch` — analyze many players at once, JSON body:
  ```json
  { "usernames": ["user1","user2"] }
  ```

CORS is preconfigured for:
- https://chessdev-hub.github.io
- https://chessdev-hub.github.io/sus-scanner

---

## 🚀 Deploy on Render (Default)

1. Create a new repo, e.g. `ChessDev-Hub/sus-scanner-api`, and push these files.
2. Go to https://render.com  → **New** → **Blueprint**.
3. Link the repo; Render will read `render.yaml`.
4. Deploy. After it’s live, copy your URL, e.g. `https://sus-scanner-api.onrender.com`.
5. Update your frontend’s `apiBase` to that URL.

---

## ☁️ Alternative: Google Cloud Run

```bash
gcloud builds submit --tag gcr.io/PROJECT_ID/sus-scanner-api
gcloud run deploy sus-scanner-api --image gcr.io/PROJECT_ID/sus-scanner-api --platform managed --allow-unauthenticated
```
Then set the frontend `apiBase` to the Cloud Run URL.
