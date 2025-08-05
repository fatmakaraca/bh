#!/usr/bin/env python3
"""
Medical Books Database Setup Script
Bu script sadece gerektiğinde medical kitapları ChromaDB'ye yükler.
Production uygulamasında otomatik çalışır.
"""

import os
import sys
from rag.rag import get_database_info, load_all_medical_books, reset_database

def get_books_config():
    """Kitap konfigürasyonunu döndür"""
    return {
        "endocrinology": "./books_data/endocrinology_chunks.json",
        "cardiology": "./books_data/cardiology_chunks.json", 
        "dermatology": "./books_data/dermatology_chunks.json",
        "neurology": "./books_data/neurology_chunks.json",
        "gastroenterology": "./books_data/gastroenterology_chunks.json",
        "pulmonology": "./books_data/pulmonology_chunks.json",
        "nephrology": "./books_data/nephrology_chunks.json",
        "infectious_diseases": "./books_data/infectious_diseases_chunks.json",
        "pediatrics": "./books_data/pediatrics_chunks.json",
        "rheumatology": "./books_data/rheumatology_chunks.json"
    }

def check_books_available():
    """Yüklenebilir kitapları kontrol et"""
    books_config = get_books_config()
    available_books = {}
    
    books_dir = "./books_data"
    if not os.path.exists(books_dir):
        return {}
    
    for specialty, file_path in books_config.items():
        if os.path.exists(file_path):
            available_books[specialty] = file_path
    
    return available_books

def setup_database_if_needed():
    """Database'i sadece gerektiğinde kur"""
    # Mevcut database durumunu kontrol et
    db_info = get_database_info()
    
    if "error" not in db_info and db_info.get('total_chunks', 0) > 0:
        print("✅ Database zaten hazır")
        return True
    
    # Yüklenebilir kitapları bul
    available_books = check_books_available()
    
    if not available_books:
        print("📭 books_data/ klasöründe kitap bulunamadı")
        print("Kitap yüklemek için JSON dosyalarınızı books_data/ klasörüne koyun")
        return False
    
    print(f"📚 {len(available_books)} kitap bulundu, database kuruluyor...")
    
    # Database'i kur
    reset_database()
    results = load_all_medical_books(available_books)
    
    # Sonuçları kontrol et
    successful_books = sum(1 for success in results.values() if success)
    
    if successful_books > 0:
        print(f"✅ Database hazır! {successful_books} kitap yüklendi")
        return True
    else:
        print("❌ Database kurulumu başarısız")
        return False
        print("    ├── endocrinology_chunks.json")
        print("    ├── cardiology_chunks.json")
        print("    └── ...")
        return False
    
    # 4. Mevcut dosyaları listele
    print(f"\n📁 {books_dir} klasöründeki dosyalar:")
    for specialty, file_path in books_config.items():
        exists = "✅" if os.path.exists(file_path) else "❌"
        print(f"  {exists} {specialty}: {file_path}")
    
    # 5. Kullanıcı onayı al
    response = input("\nDevam etmek istiyor musunuz? (y/N): ")
    if response.lower() not in ['y', 'yes', 'evet']:
        print("❌ İşlem iptal edildi.")
        return False
    
    # 6. Tüm kitapları yükle
    print("\n🚀 Kitaplar yükleniyor...")
    results = load_all_medical_books(books_config)
    
    # 7. Database durumunu kontrol et
    print("\n📊 Database Durumu:")
    info = get_database_info()
    
    if "error" in info:
        print(f"❌ Database hatası: {info['error']}")
        return False
    
    print(f"✅ Toplam chunk sayısı: {info.get('total_chunks', 0)}")
    print("📚 Yüklenen kitaplar:")
    for specialty, count in info.get('specialties', {}).items():
        print(f"  - {specialty}: {count} chunk")
    
    # 8. Başarı raporu
    successful_books = sum(1 for success in results.values() if success)
    total_books = len(results)
    
    print(f"\n🎉 Database kurulumu tamamlandı!")
    print(f"📈 Başarı oranı: {successful_books}/{total_books} kitap")
    
    if successful_books == total_books:
        print("✅ Tüm kitaplar başarıyla yüklendi!")
    elif successful_books > 0:
        print("⚠️ Bazı kitaplar yüklenemedi. Loglara bakın.")
    else:
        print("❌ Hiçbir kitap yüklenemedi. Dosya yollarını kontrol edin.")
    
    return successful_books > 0

def main():
    """Manuel database kurulumu için"""
    print("🏥 Medical Books Database Setup")
    print("=" * 50)
    
    # Mevcut durumu kontrol et
    available_books = check_books_available()
    
    if not available_books:
        print("❌ books_data/ klasöründe hiçbir kitap bulunamadı!")
        print("Lütfen JSON chunk dosyalarınızı books_data/ klasörüne koyun.")
        print("Desteklenen dosyalar:")
        for specialty in get_books_config().keys():
            print(f"  - {specialty}_chunks.json")
        return False
    
    print(f"📁 Bulunan kitaplar:")
    for specialty in available_books.keys():
        print(f"  ✅ {specialty}")
    
    # Kullanıcı onayı al
    response = input(f"\n{len(available_books)} kitap yüklenecek. Devam etmek istiyor musunuz? (y/N): ")
    if response.lower() not in ['y', 'yes', 'evet']:
        print("❌ İşlem iptal edildi.")
        return False
    
    # Database'i kur
    return setup_database_if_needed()

def check_database():
    """Mevcut database durumunu kontrol et"""
    print("🔍 Database Durumu Kontrolü")
    print("=" * 30)
    
    info = get_database_info()
    
    if "error" in info:
        print(f"❌ Database hatası: {info['error']}")
        return
    
    total_chunks = info.get('total_chunks', 0)
    if total_chunks == 0:
        print("📭 Database boş")
        available_books = check_books_available()
        if available_books:
            print(f"📚 {len(available_books)} kitap yüklenmeye hazır")
            print("Database kurmak için: python setup_database.py")
        else:
            print("❌ books_data/ klasöründe kitap bulunamadı")
        return
    
    print(f"✅ Toplam chunk sayısı: {total_chunks}")
    print("📚 Mevcut kitaplar:")
    for specialty, count in info.get('specialties', {}).items():
        print(f"  - {specialty}: {count} chunk")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "check":
        check_database()
    else:
        main()
