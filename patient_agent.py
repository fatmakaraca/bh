import random
import json
import os
import time
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.chains import ConversationChain
from langchain.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain.schema import SystemMessage
from google.api_core.exceptions import ResourceExhausted
from langchain.memory import ConversationBufferMemory
import google.generativeai as genai

load_dotenv()
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

# random hasta seçimi
def load_random_patient(area: str, base_path="./patient_data"):
    path = os.path.join(base_path, area)
    print(f"Yüklenmek istenen klasör: {path}")

    if not os.path.exists(path):
        raise Exception(f"Klasör bulunamadı: {path}")

    files = [f for f in os.listdir(path) if f.endswith(".json")]
    if not files:
        raise Exception(f"{path} klasöründe json dosyası yok.")

    chosen = random.choice(files)
    print(f"Seçilen hasta dosyası: {area}/{chosen}")

    with open(os.path.join(path, chosen), 'r', encoding='utf-8') as f:
        data = json.load(f)

    cases = data.get("disease_info", {}).get("cases", [])
    if not cases:
        raise Exception("Seçilen dosyada hiç vaka bulunamadı.")

    # Tek vaka varsa direkt onu al
    return cases[0]



# sistem promptu hazırlama
def create_system_prompt(patient_data, doctor_gender):
    profile = patient_data.get("patient_profile", {})

    name = profile.get("name", "Bilinmiyor")
    age = profile.get("age", "Bilinmiyor")
    gender = profile.get("gender", "Bilinmiyor")

    # Yaş birimi opsiyonel
    age_unit = profile.get("age_unit", "")
    age_str = f"{age} {age_unit}".strip()

    # Semptomlar (sözlükse düzleştir)
    symptoms_raw = profile.get("symptoms", {})
    if isinstance(symptoms_raw, dict):
        symptoms = ", ".join([f"{k}: {v}" for k, v in symptoms_raw.items()])
    else:
        symptoms = symptoms_raw or "Belirtilmemiş"

    # Tıbbi geçmiş
    history_raw = profile.get("medical_history")
    if isinstance(history_raw, list):
        history = ", ".join(history_raw)
    elif isinstance(history_raw, str):
        history = history_raw
    else:
        history = "Yok"

    # Güncel hikaye (history)
    patient_story = profile.get("history", "Belirtilmemiş")

    # Vital bulgular
    vitals = profile.get("vital_signs", {})
    vitals_str = ", ".join([f"{k}: {v}" for k, v in vitals.items()]) if vitals else "Yok"

    # Fizik muayene
    physical = profile.get("physical_exam", {})
    physical_str = ", ".join([f"{k}: {v}" for k, v in physical.items()]) if physical else "Yok"

    # Laboratuvar
    lab = profile.get("laboratory", {})
    lab_str = ", ".join([f"{k}: {v}" for k, v in lab.items()]) if lab else "Yok"

    # Görüntüleme verisi varsa
    images = profile.get("imaging", {})
    image_str = ", ".join([f"{k}: {v}" for k, v in images.items()]) if images else "Yok"

    # İlaçlar
    meds = profile.get("medications", [])
    meds_str = ", ".join(meds) if meds else "Yok"

    # Aile öyküsü
    family_history_raw = profile.get("family_history")
    if isinstance(family_history_raw, list):
        family_history = ", ".join(family_history_raw)
    elif isinstance(family_history_raw, str):
        family_history = family_history_raw
    else:
        family_history = "Yok"

    # Sosyal öykü
    social = profile.get("social_history", [])
    social_str = ", ".join(social) if social else "Yok"

    # Doktora hitap
    honorific = "Doktor Hanım" if doctor_gender == "kadın" else "Doktor Bey"


    prompt = f"""
    Sen gerçek bir hastasın. Bir tıp öğrencisi seninle görüşme yapıyor. 
    Doktorun cinsiyeti: {doctor_gender}. Ona hitap ederken "{honorific}" şeklinde seslen.

    Aşağıdaki bilgiler sana aittir:

    👤 **Ad**: {name}  
    📅 **Yaş**: {age_str}  
    🚻 **Cinsiyet**: {gender}  
    🤒 **Semptomlar**: {symptoms} 
    Güncel Hikaye: {patient_story} 
    📖 **Tıbbi Geçmiş**: {history}  
    👨‍👩‍👧 **Aile Öyküsü**: {family_history}  
    🧬 **Sosyal Öykü**: {social_str}  
    💊 **Kullanılan İlaçlar**: {meds_str}  
     
    Hastalık adını sakla ve sadece öğrenci sorduğunda cevapla.
    Soruları gerçek bir hasta gibi yanıtla.
    Gereksiz bilgi verme, sorulmadıkça teşhisi söyleme. 
    """
    return prompt.strip()


# Hafıza oluşturma fonksiyonu
def create_memory():
    return ConversationBufferMemory(return_messages=True)


# LLM modelini başlatma fonksiyonu
def initialize_llm(model_name="models/gemini-1.5-pro-latest", temperature=0.7):
    return ChatGoogleGenerativeAI(
        model=model_name,
        temperature=temperature,
        google_api_key=GOOGLE_API_KEY
    )


# Chat modeli ve memory ayarlama
def create_conversation_chain(llm_instance, system_prompt, memory):
    prompt = ChatPromptTemplate.from_messages([
        SystemMessage(content=system_prompt),
        MessagesPlaceholder(variable_name="history"),
        ("human", "{input}")
    ])
    chain = ConversationChain(
        llm=llm_instance,
        prompt=prompt,
        memory=memory,
        verbose=True
    )
    return chain

def list_supported_models():
    try:
        genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
        print("Desteklenen Modeller:")
        for m in genai.list_models():
            # 'generateContent' metodunu destekleyen modelleri filtreliyoruz
            if 'generateContent' in m.supported_generation_methods:
                print(f"Model Adı: {m.name}, Açıklama: {m.description}")
    except Exception as e:
        print(f"Hata oluştu: {e}")

def get_response(user_input, memory, llm_instance, system_prompt):
    try:
        chain = create_conversation_chain(llm_instance, system_prompt, memory)
        response = chain.predict(input=user_input)
        return response, chain.memory
    except Exception as e:
        return f"Hata oluştu: {str(e)}", memory
