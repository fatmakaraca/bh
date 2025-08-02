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
    diagnostics = patient_data.get("diagnostic_tests", {})

    # Semptomlar (chief_complaint'ten al)
    symptoms = profile.get("symptoms", "Belirtilmemiş")

    # Tıbbi geçmiş
    history_raw = profile.get("history")
    if isinstance(history_raw, list):
        history = ", ".join(history_raw)
    elif isinstance(history_raw, str):
        history = history_raw
    else:
        history = "Yok"

    # Laboratuvar sonuçları
    lab_data = diagnostics.get("laboratory")
    if isinstance(lab_data, dict):
        lab_str = ", ".join([f"{k}: {v}" for k, v in lab_data.items()])
    elif isinstance(lab_data, str):
        lab_str = lab_data
    else:
        lab_str = "Yok"

    # Yaş
    age = profile.get("age", "Bilinmiyor")
    age_unit = profile.get("age_unit", "")  # opsiyonel
    age_str = f"{age} {age_unit}".strip()

    # Cinsiyet
    gender = profile.get("gender", "Bilinmiyor")

    prompt = f"""
    Sen gerçek bir hastasın. Tıp öğrencisi seninle görüşüyor. 
    Doktorun cinsiyeti: {doctor_gender}. Doktora hitap etmen gerekirse doktor kadınsa, "Doktor Hanım" şeklinde, erkekse "Doktor Bey" şeklinde hitap et.
    Sana ait bilgiler:
    Yaş: {age_str}
    Cinsiyet: {profile.get("gender", "Bilinmiyor")}
    Semptomlar: {symptoms}
    Tıbbi geçmiş: {history}
    Laboratuvar sonuçları: {lab_str}

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

GEMINI_MODELS = [
        # Güncel ve hızlı Flash modeller
        "models/gemini-1.5-flash-latest",
        "models/gemini-1.5-flash-002",
        "models/gemini-2.5-flash",
        "models/gemini-2.5-flash-lite",

        # Daha güçlü Pro modeller (daha fazla kota tüketir)
        "models/gemini-1.5-pro-latest",
        "models/gemini-1.5-pro-002",
        "models/gemini-2.5-pro",

        # Flash-8B modelleri, küçük boyutlu ve uygun maliyetli
        "models/gemini-1.5-flash-8b",
        "models/gemini-1.5-flash-8b-001",
        "models/gemini-1.5-flash-8b-latest",
    ]

if __name__ == "__main__":
    # Hasta seç
    folder_name = input("Hangi alanda hasta seçilsin? (örnek: pediatri): ").strip()
    doctor_gender = input("cinsiyetiniz nedir?: (kadın/erkek)").strip()

    try:
        patient = load_random_patient(area=folder_name)  # ✅ DÜZELTİLDİ
    except Exception as e:
        print(f"Hasta yüklenemedi: {e}")
        exit(1)

    # Promptu oluştur
    system_prompt = create_system_prompt(patient, doctor_gender)
    print("=== Sistem Promptu ===")
    print(system_prompt)

    current_model_index = 0
    current_model_name = GEMINI_MODELS[current_model_index]

    llm = initialize_llm(current_model_name)
    memory = create_memory()
    conversation = create_conversation_chain(llm, system_prompt, memory)

    current_turn = "doktor"
    last_user_input = None

    print("\nHasta simülasyonu başladı. 'exit' yazarak çıkabilirsiniz.\n")
    while True:
        print(f"\nŞu anki model: {current_model_name}")

        if current_turn == "doktor":
            user_input = input("👨‍⚕️ Doktor: ").strip()
            if user_input.lower() in ["exit", "çık", "quit"]:
                print("Simülasyon sonlandırılıyor...")
                break
            if not user_input:
                print("Boş mesaj gönderilemez.")
                continue

            last_user_input = user_input  # kota dolarsa tekrar kullanmak için sakla
            current_turn = "hasta"

        if current_turn == "hasta":
            while True:
                try:
                    response = conversation.predict(input=last_user_input)
                    print(f"🧑‍🦰 Hasta: {response}")
                    break  # başarılıysa döngüden çık
                except ResourceExhausted:
                    print(f"Kota doldu: {current_model_name}. Sıradaki modele geçiliyor.")
                    current_model_index += 1
                    if current_model_index >= len(GEMINI_MODELS):
                        print("Tüm modeller doldu. 10 dakika bekleniyor...")
                        time.sleep(600)
                        current_model_index = 0

                    current_model_name = GEMINI_MODELS[current_model_index]
                    llm = initialize_llm(current_model_name)
                    conversation = create_conversation_chain(llm, system_prompt, memory)
                    print(f"Yeni modele geçildi: {current_model_name}")
                    continue
                except Exception as e:
                    print(f"Beklenmeyen hata oluştu: {e}")
                    break  # diğer hatalarda döngüden çık

            current_turn = "doktor"


