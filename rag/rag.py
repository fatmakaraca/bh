# rag.py
import os
from dotenv import load_dotenv
import chromadb

load_dotenv()
model_path = os.getenv("MODEL_PATH")

# Lazy loading için global değişkenler
llm = None
chroma_client = None
collection = None

def initialize_llm():
    """LLM'i lazy loading ile başlat"""
    global llm
    if llm is None:
        try:
            from llama_cpp import Llama
            llm = Llama(model_path=model_path, n_ctx=2048, n_threads=6, verbose=False)
        except Exception as e:
            print(f"LLM initialization failed: {e}")
            llm = "error"
    return llm

def initialize_chroma():
    """ChromaDB'yi lazy loading ile başlat"""
    global chroma_client, collection
    if chroma_client is None:
        try:
            # Eski database'i sil ve yeniden oluştur
            import shutil
            db_path = "./rag/db"
            if os.path.exists(db_path):
                shutil.rmtree(db_path)
            
            chroma_client = chromadb.PersistentClient(path=db_path)
            collection = chroma_client.get_or_create_collection(name="my_collection")
        except Exception as e:
            print(f"ChromaDB initialization failed: {e}")
            chroma_client = "error"
            collection = "error"
    return chroma_client, collection

def add_to_db(doc_id, content):
    """Dokümanı veritabanına ekle"""
    try:
        _, coll = initialize_chroma()
        if coll == "error":
            raise Exception("ChromaDB not available")
        coll.add(documents=[content], ids=[doc_id])
        return True
    except Exception as e:
        print(f"Error adding to DB: {e}")
        return False

def query_db(query):
    """Veritabanından sorgu yap"""
    try:
        _, coll = initialize_chroma()
        if coll == "error":
            return ""
        results = coll.query(query_texts=[query], n_results=1)
        return results["documents"][0][0] if results["documents"] else ""
    except Exception as e:
        print(f"Error querying DB: {e}")
        return ""

def ask_llm(question):
    """LLM'e soru sor"""
    try:
        model = initialize_llm()
        if model == "error":
            return "LLM is not available. Please check your model configuration."
        
        context = query_db(question)
        if context:
            prompt = f"Context:\n{context}\n\nQuestion: {question}\nAnswer:"
        else:
            prompt = f"Question: {question}\nAnswer:"
        
        response = model(prompt, max_tokens=300, stop=["Q:", "User:"])
        return response["choices"][0]["text"].strip()
    except Exception as e:
        return f"Error from LLM: {str(e)}"

def answer_question(question: str) -> str:
    """Ana fonksiyon - soruya cevap ver"""
    try:
        return ask_llm(question)
    except Exception as e:
        return f"Error: {str(e)}"

