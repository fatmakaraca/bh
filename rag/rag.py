# rag.py
import os
import json
import shutil
import requests
from dotenv import load_dotenv
import chromadb
from typing import Dict, List, Optional
import google.generativeai as genai

load_dotenv()

# Lazy loading için global değişkenler
chroma_client = None
collection = None

def ensure_database_ready():
    """Production'da database'in hazır olduğundan emin ol"""
    try:
        # Database durumunu kontrol et
        db_info = get_database_info()
        
        if "error" not in db_info and db_info.get('total_chunks', 0) > 0:
            print("✅ Database hazır")
            return True
        
        # Database boşsa otomatik kur
        print("📋 Database boş, otomatik kurulum başlatılıyor...")
        from setup_database import setup_database_if_needed
        return setup_database_if_needed()
        
    except Exception as e:
        print(f"⚠️ Database kontrol hatası: {e}")
        return False


def initialize_chroma():
    """ChromaDB'yi lazy loading ile başlat - GÜNCELLENEN VERSİYON"""
    global chroma_client, collection
    if chroma_client is None:
        try:
            # Absolute path kullan - working directory sorunlarını önlemek için
            current_dir = os.path.dirname(os.path.abspath(__file__))
            db_path = os.path.join(current_dir, "db")
            
            print(f"🔍 ChromaDB initialize - current_dir: {current_dir}")
            print(f"🔍 ChromaDB initialize - db_path: {db_path}")
            print(f"🔍 ChromaDB initialize - db_path exists: {os.path.exists(db_path)}")
            
            chroma_client = chromadb.PersistentClient(path=db_path)
            # Artık database'i silmiyoruz, mevcut koleksiyonu kullanıyoruz
            collection = chroma_client.get_or_create_collection(name="medical_books")
            
            print(f"✅ ChromaDB başarıyla başlatıldı")
        except Exception as e:
            print(f"❌ ChromaDB initialization failed: {e}")
            import traceback
            traceback.print_exc()
            chroma_client = "error"
            collection = "error"
    return chroma_client, collection

def reset_globals():
    """Global değişkenleri sıfırla"""
    global chroma_client, collection, llm
    chroma_client = None
    collection = None
    print("🔄 Global değişkenler sıfırlandı")

def reset_database():
    """Database'i sıfırla (sadece setup sırasında kullan)"""
    try:
        # Absolute path kullan
        current_dir = os.path.dirname(os.path.abspath(__file__))
        db_path = os.path.join(current_dir, "db")
        
        if os.path.exists(db_path):
            shutil.rmtree(db_path)
        print("✅ Database sıfırlandı")
        
        # Global değişkenleri de sıfırla
        global chroma_client, collection
        chroma_client = None
        collection = None
        
    except Exception as e:
        print(f"❌ Database sıfırlama hatası: {e}")

def load_book_to_db(specialty: str, json_file_path: str) -> bool:
    """Bir kitabın chunk'larını database'e yükle"""
    try:
        # JSON dosyasını oku
        with open(json_file_path, 'r', encoding='utf-8') as f:
            chunks = json.load(f)
        
        # ChromaDB'yi başlat
        _, coll = initialize_chroma()
        if coll == "error":
            print(f"❌ ChromaDB hatası")
            return False
        
        documents = []
        metadatas = []
        ids = []
        
        print(f"📚 {specialty} kitabı yükleniyor: {len(chunks)} chunk")
        
        for i, chunk in enumerate(chunks):
            # Unique ID oluştur
            chunk_id = f"{specialty}_{i}"
            
            # Document content
            content = chunk.get('content', chunk.get('text', ''))
            if not content:
                print(f"⚠️ Boş chunk atlanıyor: {chunk_id}")
                continue
                
            documents.append(content)
            
            # Metadata oluştur
            metadata = {
                "specialty": specialty,
                "book_title": chunk.get('book_title', f"{specialty.title()} Medical Book"),
                "page_number": str(chunk.get('page_number', chunk.get('page', 'Unknown'))),
                "chunk_index": i,
                "source_type": "medical_textbook"
            }
            metadatas.append(metadata)
            ids.append(chunk_id)
        
        # Batch olarak database'e ekle
        if documents:
            coll.add(
                documents=documents,
                metadatas=metadatas,
                ids=ids
            )
            print(f"✅ {specialty} başarıyla yüklendi: {len(documents)} chunk")
            return True
        else:
            print(f"❌ {specialty} için hiç geçerli chunk bulunamadı")
            return False
            
    except Exception as e:
        print(f"❌ {specialty} yükleme hatası: {e}")
        return False

def load_all_medical_books(books_config: Dict[str, str]) -> Dict[str, bool]:
    """Tüm kitapları database'e yükle"""
    results = {}
    
    print("🚀 Tüm medical kitaplar yükleniyor...")
    print("=" * 50)
    
    for specialty, file_path in books_config.items():
        if os.path.exists(file_path):
            success = load_book_to_db(specialty, file_path)
            results[specialty] = success
        else:
            print(f"❌ Dosya bulunamadı: {file_path}")
            results[specialty] = False
    
    print("=" * 50)
    print("📊 Yükleme Özeti:")
    for specialty, success in results.items():
        status = "✅ Başarılı" if success else "❌ Hatalı"
        print(f"  {specialty}: {status}")
    
    return results

def query_db_by_specialty(query: str, specialty: str = None, n_results: int = 3) -> Dict:
    """Specialty'ye göre filtrelenmiş sorgu"""
    try:
        _, coll = initialize_chroma()
        if coll == "error":
            return {"documents": [], "metadatas": []}
        
        # Metadata filtreleme
        where_filter = None
        if specialty:
            where_filter = {"specialty": specialty}
        
        results = coll.query(
            query_texts=[query], 
            n_results=n_results,
            where=where_filter
        )
        
        return results
    except Exception as e:
        print(f"❌ Database sorgu hatası: {e}")
        return {"documents": [], "metadatas": []}

def get_database_info() -> Dict:
    """Database bilgilerini getir"""
    try:
        _, coll = initialize_chroma()
        if coll == "error":
            return {"error": "ChromaDB kullanılamıyor"}
        
        # Tüm metadataları al
        results = coll.get()
        
        if not results.get("metadatas"):
            return {"total_chunks": 0, "specialties": []}
        
        # Specialty'leri say
        specialties = {}
        for metadata in results["metadatas"]:
            specialty = metadata.get("specialty", "unknown")
            specialties[specialty] = specialties.get(specialty, 0) + 1
        
        return {
            "total_chunks": len(results["metadatas"]),
            "specialties": specialties,
            "available_books": list(specialties.keys())
        }
    except Exception as e:
        return {"error": f"Database bilgi alma hatası: {e}"}

def add_to_db(doc_id, content):
    """Eski API - geriye uyumluluk için"""
    print("⚠️ add_to_db deprecated. Use load_book_to_db instead.")
    return False

def query_db(query):
    """Eski API - geriye uyumluluk için"""
    results = query_db_by_specialty(query)
    if results.get("documents") and results["documents"][0]:
        return results["documents"][0][0]
    return ""

def translate_text(text: str, target_language: str = "en", model_name: str = "models/gemini-1.5-pro-latest") -> str:
    """
    Gemini ile çeviri yapan fonksiyon.
    """
    prompt = f"Lütfen şu metni {target_language.upper()} diline çevir:\n\n{text}"
    return ask_gemini_api(prompt, model_name=model_name)


def ask_gemini_api(prompt: str, model_name: str = "models/gemini-1.5-pro-latest", max_tokens=500, temperature=0.7) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Gemini API anahtarı bulunamadı. Lütfen .env dosyasını kontrol edin.")

    genai.configure(api_key=api_key)
    
    try:
        # Modeli başlat (örneğin gemini-pro kullanılıyor)
        model = genai.GenerativeModel(model_name=model_name)

        # Prompt gönder
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": temperature,
                "max_output_tokens": max_tokens
            }
        )

        return response.text.strip()

    except Exception as e:
        raise RuntimeError(f"Gemini SDK Hatası: {str(e)}")

def answer_question(question: str, specialty: str = None, model: str = "models/gemini-1.5-pro-latest") -> Dict:
    try:
        if "[ENDOCRINOLOGY]" in question:
            specialty = "endocrinology"
            question = question.replace("[ENDOCRINOLOGY]", "").strip()
        db_results = query_db_by_specialty(question, specialty, n_results=3)
        if not db_results.get("documents") or not db_results["documents"][0]:
            return {
                "answer": "Üzgünüm, bu konuda bilgi bulamadım.",
                "source_metadata": None,
                "query_info": {
                    "specialty_filter": specialty,
                    "results_found": 0
                }
            }
        context = db_results["documents"][0][0]
        metadata = db_results["metadatas"][0][0] if db_results.get("metadatas") else {}
        prompt = f"""
Context: {context}

Question: {question}

Answer based on the medical context provided:
"""
        llm_answer = ask_gemini_api(prompt, model_name=model, max_tokens=500, temperature=0.7)
        book_title = metadata.get("book_title", "Unknown")
        page_number = metadata.get("page_number", "Unknown")
        answer_with_source = f"This information is from {book_title}'s {page_number}th page:\n\n{llm_answer}"
        return {
            "answer": answer_with_source,
            "source_metadata": {
                "book_title": book_title,
                "page_number": page_number,
                "specialty": metadata.get("specialty", "Unknown")
            },
            "query_info": {
                "specialty_filter": specialty,
                "results_found": len(db_results["documents"][0])
            }
        }
    except Exception as e:
        print(f"❌ answer_question hatası: {e}")
        return {
            "answer": f"Bir hata oluştu: {str(e)}",
            "source_metadata": None,
            "query_info": None
        }


