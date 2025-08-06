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
from fastapi.middleware.cors import CORSMiddleware

from rag.rag import answer_question, get_database_info, ensure_database_ready
from enum import Enum

model_index_key_for_query = "query:model_index"

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redis bağlantısı
REDIS_URL = os.getenv("REDIS_URL")
r = redis.from_url(REDIS_URL, decode_responses=True)

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


@app.post("/reset")
def reset_session(session_id: str):
    memory_key = f"session:{session_id}"
    r.delete(memory_key)
    r.delete(f"{memory_key}:prompt")
    r.delete(f"{memory_key}:model_index")
    return {"message": f"{session_id} oturumu sıfırlandı."}


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

    patient_key = f"session:{session_id}:patient"
    patient_json = r.get(patient_key)

    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")

    patient_data = json.loads(patient_json)
    correct_diagnosis = patient_data.get("correct_diagnosis", "")

    key = f"session:{session_id}:diagnosis"
    r.set(key, diagnosis)

    correct_diagnosis_main = re.split(r"\s*\(", correct_diagnosis)[0].strip().lower()
    diagnosis_main = diagnosis.strip().lower()

    is_correct = diagnosis_main == correct_diagnosis_main

    if correct_diagnosis:
        if is_correct:
            result = f"Tebrikler, doğru teşhis! Hastalık: {correct_diagnosis}"
        else:
            result = f"Yanlış teşhis. Doğru cevap: {correct_diagnosis}"
    else:
        result = "Doğru teşhis bilgisi JSON içinde tanımlı değil."

    return {
        "message": result,
        "session_id": session_id,
        "your_diagnosis": diagnosis,
        "correct_diagnosis": correct_diagnosis,
        "is_correct": is_correct
    }

@app.get("/patient_info")
def get_patient_info(session_id: str):
    patient_key = f"session:{session_id}:patient"
    patient_json = r.get(patient_key)

    if not patient_json:
        raise HTTPException(status_code=404, detail="Hasta verisi bulunamadı.")

    patient_data = json.loads(patient_json)
    name = patient_data.get("patient_profile", {}).get("name", "Bilinmiyor")
    age = patient_data.get("patient_profile", {}).get("age", "Bilinmiyor")
    age_unit = patient_data.get("patient_profile", {}).get("age_unit", "yaş")
    age_str = f"{age} {age_unit}".strip()
    gender = patient_data.get("patient_profile", {}).get("gender", "Bilinmiyor")

    correct_diagnosis = patient_data.get("correct_diagnosis", "Tanı bilgisi yok")

    return {
        "patient_name": name,
        "patient_age": age_str,
        "patient_gender": gender,
        "correct_diagnosis": correct_diagnosis
    }

@app.on_event("startup")
async def startup_event():
    """Uygulama başlarken database'in hazır olduğundan emin ol"""
    ensure_database_ready()




# Medical specialties enum
class MedicalSpecialty(str, Enum):
    DERMATOLOGY = "dermatoloji"
    CARDIOLOGY = "kardiyoloji"
    ENDOCRINOLOGY = "endokrinoloji"
    NEUROLOGY = "nöroloji"
    GASTROENTEROLOGY = "gastroenteroloji"
    PULMONOLOGY = "pulmonoloji"
    NEPHROLOGY = "nefroloji"
    INFECTIOUS_DISEASES = "enfeksiyon_hastalıkları"
    PEDIATRICS = "pediatri"
    RHEUMATOLOGY = "romatoloji"

class SpecialtyQueryRequest(BaseModel):
    question: str
    specialty: MedicalSpecialty

@app.post("/query")
async def query_by_specialty(request: SpecialtyQueryRequest):
    """Seçilen uzmanlık alanına göre medical soru sorma"""
    try:
        specialty_map = {
            MedicalSpecialty.ENDOCRINOLOGY: "endocrinology",
            MedicalSpecialty.CARDIOLOGY: "cardiology",
            MedicalSpecialty.DERMATOLOGY: "dermatology",
            MedicalSpecialty.NEUROLOGY: "neurology",
            MedicalSpecialty.GASTROENTEROLOGY: "gastroenterology",
            MedicalSpecialty.PULMONOLOGY: "pulmonology",
            MedicalSpecialty.NEPHROLOGY: "nephrology",
            MedicalSpecialty.INFECTIOUS_DISEASES: "infectious_diseases",
            MedicalSpecialty.PEDIATRICS: "pediatrics",
            MedicalSpecialty.RHEUMATOLOGY: "rheumatology"
        }

        mapped_specialty = specialty_map.get(request.specialty, request.specialty.value.lower())

        db_info = get_database_info()
        available_books = db_info.get("available_books", [])

        if mapped_specialty not in available_books:
            return {
                "question": request.question,
                "specialty": request.specialty,
                "answer": f"📚 {request.specialty.title()} kitabı henüz yüklenmemiş.",
                "status": "book_not_available",
                "available_books": available_books,
                "database_info": db_info
            }


        # Redis'ten mevcut model index'i al (yoksa 0)
        current_index = int(r.get(model_index_key_for_query) or 0)

        # Model listesi (GEMINI_MODELS global değişken olmalı)
        max_index = len(GEMINI_MODELS) - 1

        while True:
            try:
                # Kullanılacak model adı
                model_name = GEMINI_MODELS[current_index]

                rag_result = answer_question(request.question, specialty=mapped_specialty, model=model_name)
                # Başarılıysa sonucu dön
                if isinstance(rag_result, dict):
                    answer_text = rag_result.get("answer", str(rag_result))
                    source_info = {}
                    if rag_result.get("source_metadata"):
                        metadata = rag_result["source_metadata"]
                        source_info = {
                            "book_title": metadata.get("book_title", "Unknown"),
                            "page_number": metadata.get("page_number", "Unknown"),
                            "specialty": metadata.get("specialty", "Unknown")
                        }
                else:
                    answer_text = str(rag_result)
                    source_info = {}

                # Kullanılan modeli ve index'i redis'e yaz
                r.set(model_index_key_for_query, current_index)

                return {
                    "question": request.question,
                    "specialty": request.specialty,
                    "mapped_specialty": mapped_specialty,
                    "answer": answer_text,
                    "status": "success",
                    "source_details": source_info,
                    "model": model_name,
                    "query_info": rag_result.get("query_info") if isinstance(rag_result, dict) else None
                }

            except ResourceExhausted:
                # Kota dolduğunda indeksi artır
                current_index += 1
                if current_index > max_index:
                    # Tüm modeller dolduysa biraz bekle ve başa dön
                    print("Tüm modellerin kotası doldu. 10 dakika bekleniyor...")
                    time.sleep(600)
                    current_index = 0
                # Redis'te güncelle
                r.set(model_index_key_for_query, current_index)

            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")



@app.get("/redis/keys")
def list_redis_keys():
    try:
        keys = r.keys("*")
        result = {}
        for key in keys:
            try:
                val = r.get(key)
                result[key] = val
            except Exception as e:
                result[key] = f"Hata: {str(e)}"
        return {"redis_keys": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/redis/set_model_index")
def set_model_index(index: int):
    try:
        r.set("query:model_index", index)
        return {"message": f"query:model_index değeri {index} olarak güncellendi."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

