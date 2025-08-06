import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:btk_demo/services/api_service.dart';
import 'package:translator/translator.dart';

class SourceView extends StatefulWidget {
  final String? area;
  final String? correctDiagnosis;

  const SourceView({super.key, this.area, this.correctDiagnosis});

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> {
  bool _isLoading = false;
  String? _answer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSourceInfo();
  }

  Future<void> _loadSourceInfo() async {
    print('SourceView Debug:');
    print('Area:  [32m${widget.area} [0m');
    print('Correct Diagnosis:  [32m${widget.correctDiagnosis} [0m');

    if (widget.area == null || widget.correctDiagnosis == null) {
      print('Missing required data');
      setState(() {
        _error = 'Gerekli bilgiler eksik';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    String diagnosisToAsk = widget.correctDiagnosis!;
    final translator = GoogleTranslator();
    try {
      var translation = await translator.translate(
        diagnosisToAsk,
        from: 'tr',
        to: 'en',
      );
      diagnosisToAsk = translation.text;
      print('Çeviri sonucu: $diagnosisToAsk');
    } catch (e) {
      print('Çeviri başarısız, Türkçe ile devam ediliyor. Hata: $e');
    }

    try {
      final question = "What is $diagnosisToAsk?";
      print('Generated Question: $question');

      final response = await ApiService.sendQuery(
        question: question,
        speciality: widget.area!,
      );

      print('SourceView Response: $response');

      if (mounted) {
        String finalAnswer = response?['answer'];

        try {
          var translated = await translator.translate(
            finalAnswer,
            from: 'en',
            to: 'tr',
          );
          finalAnswer = translated.text;
          print('Cevap Türkçeye çevrildi: $finalAnswer');
        } catch (e) {
          print('Cevap çevirisi başarısız, İngilizce gösteriliyor. Hata: $e');
        }

        setState(() {
          _isLoading = false;
          _answer = finalAnswer;
        });
      }
    } catch (e) {
      print('SourceView Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Bağlantı hatası oluştu';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Kaynak Bilgileri',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 87, 134, 150),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: 'Ana Sayfa',
            onPressed: () => context.go('/anasayfa'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 80, 125, 140),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kaynak bilgileri yükleniyor...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color.fromARGB(255, 80, 125, 140),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu işlem biraz zaman alabilir',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadSourceInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 80, 125, 140),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teşhis bilgisi
                  if (widget.correctDiagnosis != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.remember_me_outlined,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Doğru Teşhis:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 80, 125, 140),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.correctDiagnosis!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Alan bilgisi
                  if (widget.area != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: const Color.fromARGB(255, 78, 181, 150),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Uzmanlık Alanı:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 80, 125, 140),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.area!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 92, 194, 150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Kaynak bilgileri
                  if (_answer != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book,
                                color: const Color.fromARGB(255, 80, 125, 140),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Kaynak Bilgileri:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 80, 125, 140),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _answer!,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Color(0xFF414A4C),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
