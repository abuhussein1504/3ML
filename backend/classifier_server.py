from __future__ import annotations

import os
import sys
from contextlib import asynccontextmanager
from pathlib import Path

import torch
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from transformers import AutoModelForSequenceClassification, AutoTokenizer

_REPO_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_MODEL = _REPO_ROOT / "classifier" / "3ml-classifier-distilbert"
MODEL_PATH = Path(os.environ.get("M3L_CLASSIFIER_MODEL", str(_DEFAULT_MODEL))).resolve()

clf_tokenizer = None
clf_model = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global clf_tokenizer, clf_model

    if not MODEL_PATH.is_dir():
        print(f"\n[ERROR] Model directory not found: {MODEL_PATH}")
        print("Set M3L_CLASSIFIER_MODEL or place the export under classifier/3ml-classifier-distilbert\n")
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"\n{'=' * 60}")
    print(f"Loading 3ML Classifier (DistilBERT) on {device} …")
    print(f"Model path: {MODEL_PATH}")
    print(f"{'=' * 60}")

    clf_tokenizer = AutoTokenizer.from_pretrained(str(MODEL_PATH), local_files_only=True)
    clf_model = AutoModelForSequenceClassification.from_pretrained(
        str(MODEL_PATH), local_files_only=True
    )
    clf_model.eval()
    clf_model = clf_model.to(device)

    print(f"✓  Classifier ready on {device}")
    print(f"{'=' * 60}\n")
    print("Server is live — POST /classify  body: {\"text\":\"…\"}")
    print("Press Ctrl+C to stop.\n")

    yield

    del clf_model, clf_tokenizer
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    print("Classifier unloaded.")


app = FastAPI(title="3ML Classifier", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class ClassifyRequest(BaseModel):
    text: str = Field(..., min_length=1, description="User utterance to classify")

@app.get("/health")
def health():
    return {"status": "ok", "model": "distilbert-classifier", "path": str(MODEL_PATH)}

@app.post("/classify")
def classify(req: ClassifyRequest):
    assert clf_tokenizer is not None and clf_model is not None

    inputs = clf_tokenizer(
        req.text,
        return_tensors="pt",
        truncation=True,
        padding="max_length",
        max_length=128,
    ).to(clf_model.device)

    with torch.no_grad():
        logits = clf_model(**inputs).logits

    probs = torch.softmax(logits, dim=-1)[0]
    label_id = int(torch.argmax(probs).item())
    raw_label = str(clf_model.config.id2label.get(label_id, label_id)).lower()
    confidence = round(float(probs[label_id].item()), 4)

    is_tx = (
        "transaction" in raw_label
        or "expense" in raw_label
        or raw_label in ("label_1", "1", "pos", "positive")
    )
    label = "transaction" if is_tx else "conversation"

    return {"label": label, "confidence": confidence, "text": req.text}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
