from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import redis
import uuid
import json
import re
import os
import time
from dotenv import load_dotenv
from google.api_core.exceptions import ResourceExhausted
from fastapi import Query

from patient_agent import (
    load_random_patient,
    create_system_prompt,
    create_memory,
    initialize_llm,
    create_conversation_chain,
    GEMINI_MODELS
)

# .env yükle
load_dotenv()
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

# FastAPI örneği
app = FastAPI()

# Redis bağlantısı
r = redis.Redis(host="localhost", port=6379, db=0, decode_responses=True)

# MODELLER
class MessageInput(BaseModel):
    session_id: str
    message: str
    user_gender: str = None  # Opsiyonel, "kadın" veya "erkek" olabilir

class LabTestRequest(BaseModel):
    session_id: str
    test_type: str  # Örn: "kan_tahlili"

class DiagnosisInput(BaseModel):
    session_id: str
    diagnosis: str

# 1️⃣ Alan seçme ve hasta atama
@app.post("/select_area")
def select_area(area: str, doctor_gender: str = Query(..., regex="^(kadın|erkek)$")):
    try:
        patient = load_random_patient(area)
        system_prompt = create_system_prompt(patient, doctor_gender)

        # Yeni session ID oluştur
        session_id = str(uuid.uuid4())
        memory_key = f"session:{session_id}"

        # Varsayılan model
        model_index = 0
        model_name = GEMINI_MODELS[model_index]
        llm = initialize_llm(model_name)
        memory = create_memory()
        conversation = create_conversation_chain(llm, system_prompt, memory)

        # Redis'e başlangıç bilgilerini yaz
        r.set(f"{memory_key}:prompt", system_prompt)
        r.set(f"{memory_key}:model_index", model_index)
        r.set(f"{memory_key}:patient", json.dumps(patient))
        r.set(f"{memory_key}:doctor_gender", doctor_gender)

        return {
            "message": f"{area} alanından hasta yüklendi.",
            "session_id": session_id,
            "model": model_name
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# 2️⃣ Doktor mesaj atar, hasta (Gemini) cevap döner
@app.post("/chat")
def chat(input: MessageInput):
    session_id = input.session_id.strip()
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id gerekli.")

    memory_key = f"session:{session_id}"
    prompt_key = f"{memory_key}:prompt"
    model_index_key = f"{memory_key}:model_index"

    # Mesaj temizle
    cleaned_message = re.sub(r'\s+', ' ', input.message).strip()
    if not cleaned_message:
        raise HTTPException(status_code=400, detail="Mesaj boş olamaz.")

    # Sistem promptu al
    system_prompt = r.get(prompt_key)
    if not system_prompt:
        raise HTTPException(status_code=404, detail="Sistem promptu bulunamadı. Önce /select_area çağrılmalı.")

    # Model index ve model ismi
    current_index = int(r.get(model_index_key) or 0)
    model_name = GEMINI_MODELS[current_index]
    llm = initialize_llm(model_name)

    # Hafızayı oluştur
    messages = r.lrange(memory_key, 0, -1)
    memory = create_memory()
    for m in messages:
        parsed = json.loads(m)
        memory.chat_memory.add_user_message(parsed["user"])
        memory.chat_memory.add_ai_message(parsed["bot"])

    last_user_input = cleaned_message

    # Predict ve model geçiş işlemi
    while True:
        try:
            conversation = create_conversation_chain(llm, system_prompt, memory)
            response = conversation.predict(input=last_user_input)

            # Hafızaya ekle
            r.rpush(memory_key, json.dumps({"user": last_user_input, "bot": response}))
            break
        except ResourceExhausted:
            current_index += 1
            if current_index >= len(GEMINI_MODELS):
                print("Tüm modellerin kotası doldu. 10 dakika bekleniyor...")
                time.sleep(600)
                current_index = 0

            model_name = GEMINI_MODELS[current_index]
            r.set(model_index_key, current_index)
            llm = initialize_llm(model_name)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Beklenmeyen model hatası: {str(e)}")

    return {
        "session_id": session_id,
        "model": model_name,
        "response": response
    }


# 3️⃣ Reset endpoint
@app.post("/reset")
def reset_session(session_id: str):
    memory_key = f"session:{session_id}"
    r.delete(memory_key)
    r.delete(f"{memory_key}:prompt")
    r.delete(f"{memory_key}:model_index")
    return {"message": f"{session_id} oturumu sıfırlandı."}


# 4️⃣ Sağlık kontrolü
@app.get("/status")
def health_check():
    return {"status": "OK"}


@app.get("/lab/vital_signs")
def get_vital_signs(session_id: str):
    patient_json = r.get(f"session:{session_id}:patient")
    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")
    patient_data = json.loads(patient_json)
    vital_signs = patient_data.get("patient_profile", {}).get("vital_signs", {})
    return {"vital_signs": vital_signs}


@app.get("/lab/physical_exam")
def get_physical_exam(session_id: str):
    patient_json = r.get(f"session:{session_id}:patient")
    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")
    patient_data = json.loads(patient_json)
    physical_exam = patient_data.get("patient_profile", {}).get("physical_exam", {})
    return {"physical_exam": physical_exam}


@app.get("/lab/laboratory")
def get_laboratory(session_id: str):
    patient_json = r.get(f"session:{session_id}:patient")
    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")
    patient_data = json.loads(patient_json)
    laboratory = patient_data.get("patient_profile", {}).get("laboratory", {})
    return {"laboratory": laboratory}


@app.get("/lab/imaging")
def get_imaging(session_id: str):
    patient_json = r.get(f"session:{session_id}:patient")
    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")
    patient_data = json.loads(patient_json)
    imaging = patient_data.get("patient_profile", {}).get("imaging", {})
    return {"imaging": imaging}

@app.post("/diagnose")
def submit_diagnosis(data: DiagnosisInput):
    session_id = data.session_id.strip()
    diagnosis = data.diagnosis.strip()

    if not session_id or not diagnosis:
        raise HTTPException(status_code=400, detail="session_id ve diagnosis gereklidir.")

    key = f"session:{session_id}:diagnosis"
    r.set(key, diagnosis)

    return {
        "message": "Teşhis başarıyla kaydedildi.",
        "session_id": session_id,
        "diagnosis": diagnosis
    }
