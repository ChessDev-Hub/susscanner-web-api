from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict
from scanner import analyze_player

app = FastAPI(title="SusScanner API", version="1.0.0")

origins = [
    "https://chessdev-hub.github.io",
    "https://chessdev-hub.github.io/sus-scanner",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalyzeBatchRequest(BaseModel):
    usernames: List[str]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/analyze/{username}")
def analyze(username: str):
    try:
        return analyze_player(username)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze-batch")
def analyze_batch(payload: AnalyzeBatchRequest):
    out: List[Dict] = []
    for u in payload.usernames:
        try:
            out.append(analyze_player(u))
        except Exception as e:
            out.append({"username": u, "error": str(e)})
    return {"results": out}
