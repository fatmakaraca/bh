from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from rag.rag import answer_question, get_database_info, ensure_database_ready
from enum import Enum

app = FastAPI(
    title="Medical RAG System",
    description="AI-powered medical question answering system",
    version="1.0.0"
)

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

# Ana endpoint - Specialty-based soru sorma
@app.post("/query")
async def query_by_specialty(request: SpecialtyQueryRequest):
    """Seçilen uzmanlık alanına göre medical soru sorma"""
    try:
        # Specialty mapping - enum'dan database key'ine çevir
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
        
        mapped_specialty = specialty_map.get(request.specialty, request.specialty.lower())
        
        # Database'den mevcut kitapları kontrol et
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
        
        # Specialty ile RAG sorgusu çalıştır
        rag_result = answer_question(request.question, specialty=mapped_specialty)
        
        # RAG result'ın tipini kontrol et
        if isinstance(rag_result, dict):
            # Dictionary ise source metadata'yı çıkar
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
            # String ise direkt kullan
            answer_text = str(rag_result)
            source_info = {}
        
        return {
            "question": request.question,
            "specialty": request.specialty,
            "mapped_specialty": mapped_specialty,
            "answer": answer_text,
            "status": "success",
            "source_details": source_info,
            "query_info": rag_result.get("query_info") if isinstance(rag_result, dict) else None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")