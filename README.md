# 🩺 PATSİM – Yapay Zekâ Destekli Hasta Simülasyon Uygulaması

## Proje Amacı
PATSİM,  tıp öğrencilerinin teorik bilgilerini hasta simülasyonlarıyla pratiğe dökmelerine olanak sağlayan yenilikçi bir eğitim uygulamasıdır. Proje, öğrencilerin mesleki becerilerini geliştirmeye ve klinik deneyim kazanmaya yönelik önemli katkılar sunar.
Bu uygulama sayesinde;

- Öğrenciler, gerçekçi senaryolar üzerinden hasta değerlendirme ve teşhis süreçlerini uygulayarak özgüven kazanır,

- Teorik bilgilerini aktif öğrenme yoluyla pekiştirir ve kalıcı hale getirir,

- Hasta ile etkili iletişim kurma becerilerini geliştirerek mesleki iletişim yetkinliklerini artırır,

- Hatalarını güvenli bir ortamda deneyimleyerek gerçek hasta risklerini azaltır,

- Eğitim sürecinde esneklik sağlayarak, zaman ve mekân kısıtlaması olmadan öğrenmelerine destek olur.

PATSİM, tıp eğitiminde pratik ve teoriyi birleştirerek öğrencilerin klinik hazırlıklarını güçlendiren, öğrenme deneyimini zenginleştiren ve sağlık hizmetlerinin kalitesini yükselten bir platformdur.

## Projede Kullanılan Teknolojiler
- Gemini (Google Generative AI): Tıbbi sorulara doğal dilde yanıtlar üretmek için kullanılmıştır. Yapay zekâya kullanıcı soruları gönderilerek bilgiye dayalı akıllı yanıtlar elde edilmiştir.
- LangChain: Prompt yönetimi, veri bağlantıları ve bellek yönetimi gibi işlemleri kolaylaştırmak için tercih edilmiştir.
- FastAPI: rojemizde RESTful API yapısını oluşturmak, güvenilir ve hızlı bir backend sağlamak amacıyla tercih edilmiştir. Asenkron destekli yapısıyla yapay zekâ entegrasyonlarında performans avantajı sağlar.
- Redis: API yanıtlarını önbelleğe almak, oturum yönetimi sağlamak ve kullanıcı deneyimini hızlandırmak amacıyla kullanılmıştır. Gerçek zamanlı işlemler için oldukça etkilidir.
- RAG (Retrieval-Augmented Generation): Bu projede, LLM tabanlı hasta simülasyon sisteminin bilgi tabanını genişletmek amacıyla RAG (Retrieval-Augmented Generation) mimarisi kullanılmıştır. RAG, klasik dil modellerine kıyasla daha güncel ve doğru cevaplar üretmesini sağlar. Sistem iki temel adımdan oluşur:
  - Retrieval (Bilgi Getirme):
Kullanıcının sorduğu soruya benzer içerikler, önceden vektörleştirilmiş bir doküman veritabanından aranır. Bu projede vektör arama motoru olarak ChromaDB kullanılmıştır. Dokümanlar embedding’lere dönüştürülürken Mistral modeliyle uyumlu bir gömleme modeli tercih edilmiştir.
  - Generation (Cevap Üretimi):
Elde edilen ilgili doküman parçaları, LLM’e (bu projede Hugging Face üzerinden entegre edilen Mistral-7B-Instruct) birlikte bağlam olarak verilir. Model, bu ek bilgiyle desteklenmiş daha isabetli cevaplar üretir.
- ChromaDB: Doküman vektörlerini depolamak ve hızlı benzerlik sorguları yapmak için kullanılan vektör veritabanı.
- Sentence Transformers / HuggingFace Transformers:Embedding ve model entegrasyonları için kullanıldı.
- Flutter: Ana mobil uygulama çatısı
Platformlar arası (Android/iOS) geliştirme
- Dart: Uygulama mantığı ve UI kodlaması için kullanılan programlama dili
- Emulator/ Gerçek Cihaz Testleri
Android Emulator kullanılarak farklı cihaz çözünürlüklerinde uygulama test edildi. Gerçek cihaz (Samsung A71) ve emülatör üzerinde karşılaştırmalı denemeler yapılarak uyumluluk sağlandı.
- API isteklerinin emülatör ortamında test edilmesi için gerekli bağlantı ayarları yapılandırıldı.
- Shared Preferences: Kullanıcının verilerini cihazda kalıcı olarak saklamak için  kullanıldı

## Sistem Mimarisi



                        🧑‍⚕️ Kullanıcı
                             │
                             ▼
                 📱 Mobil Uygulama (Flutter)
                             │
                [Teşhis süreci, hasta ile etkileşim]
                             │
                             ▼
               🌐 REST API Sunucusu (FastAPI + Redis)
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
   🤖 Gemini (Hasta Simülasyonu)     📚 RAG Sistemi
                                      (Gemini + ChromaDB)
                                        │
                        [Embedding + En alakalı içerik]
                                        ▼
                           🔁 Gemini üzerinden yanıt
                             │
                             ▼
                 📲 Yanıt Mobil Uygulamaya döner




## 👥 Ekip ve İş Bölümü
- **Şeyma**:
  -  Veri Toplama ve Temizleme
  -  Metin İşleme ve Hazırlık
  - Embedding ve Vektör Veritabanı
- **Fatma**:
    - API Geliştirme (FastAPI)
    - Sunucuya Deploy Etme (Render)
    - Patient Agent Tasarımı ve Geliştirmesi (hasta rolünü üstlenen yapay zeka akışı)
- **Nehir**:
    - Mobil Uygulama Geliştirme (Flutter)
    - Arayüz Tasarımı
    - API ile Entegrasyon
      
## Kullanım Akışı
1. Uygulamaya giriş yapın ve kullanıcı hesabınızla oturum açın.

2. Simülasyon modülünden ilgili uzmanlık alanını seçin (ör. Kardiyoloji, Nöroloji, Dermatoloji).

3. Karşınıza gelen hastayla sohbet ederek hastalığını teşhis etmeye çalışın. Bu süreçte sağ üst köşede bulunan **vital bulgular**, **fizik muayene**, **laboratuvar sonuçları** ve **görüntüleme sonuçları** kısımlarından hasta hakkında bilgiler edinebilirsiniz.

4. Hastanın isim, cinsiyet, yaş, semptomları, aile öyküsü, sosyal geçmişi, tıbbi öyküsü kullandığı ilaçlar gibi verileri sorarak öğrenebilirsiniz.

5. Teşhis etmek istediğinizde **teşhis et** butonuna teşhisinizi girin, bilip bilememe durumunuz size bildirilecektir. Ayrıca teşhis yaptıktan sonra **kaynağa bak** butonu aktifleşir ve konuyla alakalı bilgi edinebilirsiniz.

6. **Bakılan Hastalar** bölümünden daha önce baktığınız hastaları inceleyebilirsiniz.


## Uygulamada Bulunan Özellikler

## 🚀 Gelecek Geliştirmeler
- RAG sistemimize daha fazla ve çeşitli tıbbi kaynaklar eklenecek.
- Gerçek ve geniş kapsamlı veri setleri toplanarak bilgi tabanı güçlendirilecek.
- Desteklenen hastalık ve uzmanlık alanları artırılacak, böylece kullanıcılar için kapsam genişleyecek.
- Modelin performans ve doğruluğu iyileştirilerek, klinik uygulamalara daha uygun sonuçlar elde edilecek.
- Alanında uzman doktorlarla iş birliği yapılarak sistemin doğruluğu, güvenilirliği ve pratik uygulamaya uygunluğu artırılacak.  

## 🎥 Uygulama Videosu 

📺 YouTube videosu: [https://www.youtube.com/watch?v=video_id](https://youtube.com/shorts/9P0P-y8oLEA )

## Canlı Demo

Backend API canlı olarak Render üzerinde yayınlanmaktadır:  
👉 [https://patsim.onrender.com](https://bh-0n6v.onrender.com)

📢 Bu endpoint üzerinden mobil uygulama, yapay zekâ destekli yanıtları almak için bağlantı kurmaktadır.

## 📫 Ekip İletişim Bilgileri

- 👤 **Fatma Karaca**  
  📧 fatmakaraca0626@gmail.com

- 👤 **Nehir Selinay Günenç**   
  📧 nehirgunenc06@gmail.com

- 👤 **Şeyma Doğan**  
  📧 seymadogan166@gmail.com
  
















