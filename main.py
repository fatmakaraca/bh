from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from rag.rag import answer_question, add_to_db

from enum import Enum

app = FastAPI(
    title="Medical RAG API",
    description="Simplified Medical Q&A API",
    version="2.0.0"
)

# Medical specialties enum
class MedicalSpecialty(str, Enum):
    DERMATOLOGY = "dermatology"
    CARDIOLOGY = "cardiology"
    ENDOCRINOLOGY = "endocrinology"
    NEUROLOGY = "neurology"
    GASTROENTEROLOGY = "gastroenterology"
    PULMONOLOGY = "pulmonology"
    NEPHROLOGY = "nephrology"
    ONCOLOGY = "oncology"

class SpecialtyQueryRequest(BaseModel):
    question: str
    specialty: MedicalSpecialty

# API çalışıyor mu çalışmıyor mu endpoint'i
@app.get("/")
async def root():
    return {"message": "Medical RAG API is working!"}

# Ana endpoint - Specialty-based soru sorma
@app.post("/query")
async def query_by_specialty(request: SpecialtyQueryRequest):
    """Seçilen uzmanlık alanına göre medical soru sorma"""
    try:
        # Şu an sadece endocrinology kitabı mevcut
        if request.specialty.lower() != "endocrinology":
            return {
                "question": request.question,
                "specialty": request.specialty,
                "answer": f"📚 {request.specialty.title()} kitabı henüz yüklenmemiş. Şu an sadece Endocrinology kitabı mevcut.",
                "status": "book_not_available",
                "available_books": ["endocrinology"]
            }
        
        # Endocrinology için specialty context'i soruya ekle
        enhanced_question = f"[ENDOCRINOLOGY] {request.question}"
        
        # Mevcut RAG engine ile sorguyu çalıştır (endocrinology kitabından)
        rag_result = answer_question(enhanced_question)
        
        # Source metadata'dan kitap bilgilerini çıkar
        source_info = {}
        if rag_result.get("source_metadata"):
            metadata = rag_result["source_metadata"]
            source_info = {
                "book_title": metadata.get("book_title", "Unknown"),
                "page_numbers": metadata.get("page_numbers", "Unknown")
            }
        
        return {
            "question": request.question,
            "specialty": request.specialty,
            "enhanced_question": enhanced_question,
            "answer": rag_result["answer"],
            "status": "success",
            "book_source": "Harrison's Endocrinology",
            "source_details": source_info
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query error: {str(e)}")

# Tüm sistemin durumunu kontrol eder (API, LLM, Database).
@app.get("/health")
def health_check():
    """Detaylı sistem sağlık kontrolü"""
    from rag.rag import initialize_llm, initialize_chroma
    
    # LLM kontrolü
    llm_status = "🟢 Working"
    try:
        llm = initialize_llm()
        if llm == "error":
            llm_status = "🔴 Error"
    except:
        llm_status = "🔴 Error"
    
    # ChromaDB kontrolü
    db_status = "🟢 Working"
    try:
        client, collection = initialize_chroma()
        if client == "error" or collection == "error":
            db_status = "🔴 Error"
    except:
        db_status = "🔴 Error"
    
    return {
        "api": "🟢 Working",
        "llm": llm_status,
        "database": db_status,
        "timestamp": datetime.now().isoformat()
    }