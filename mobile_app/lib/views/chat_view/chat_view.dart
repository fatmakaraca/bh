import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:btk_demo/services/api_service.dart';
import 'package:btk_demo/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatView extends StatefulWidget {
  final String? area;
  final String? doctorGender;

  const ChatView({super.key, this.area, this.doctorGender});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _sessionId;
  bool _isDiagnosisSubmitted = false;
  bool _isChatClosed = false;
  String? _diagnosisMessage;
  String? _patientName;
  String? _patientAge;
  bool _isCorrect = false;
  String? _correctDiagnosis;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // API'ye select_area isteği gönder
      if (widget.area != null && widget.doctorGender != null) {
        final response = await ApiService.selectArea(
          doctor_gender: widget.doctorGender!,
          area: widget.area!,
        );

        if (response != null) {
          // Session ID'yi response'dan al veya oluştur
          _sessionId =
              response['session_id'] ??
              DateTime.now().millisecondsSinceEpoch.toString();

          // Hasta bilgilerini al
          await _getPatientInfo();

          if (mounted) {
            setState(() {
              _messages.add({
                'sender': 'bot',
                'text':
                    'Merhaba Doktor ${widget.doctorGender == 'Kadın' ? 'Hanım' : 'Bey'}!',
              });
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _messages.add({
                'sender': 'bot',
                'text': 'Alan seçimi başarısız oldu. Lütfen tekrar deneyin.',
              });
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text': 'Parametreler eksik. Lütfen ana sayfadan tekrar seçin.',
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Bağlantı hatası oluştu. Lütfen tekrar deneyin.',
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          onPressed: () => context.go('/anasayfa'),
        ),
        title: const Text(
          'Hasta Kabul',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 87, 134, 150),
        elevation: 0,
        actions: [
          // Vital Signs
          IconButton(
            icon: const Icon(Icons.psychology_sharp, color: Colors.white),
            tooltip: 'Vital Bulgular',
            onPressed: _isChatClosed
                ? null
                : () => _showDataDialog('Vital Bulgular', _requestVitalSigns),
          ),
          // Physical Exam
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: Colors.white),
            tooltip: 'Fizik Muayene',
            onPressed: _isChatClosed
                ? null
                : () => _showDataDialog('Fizik Muayene', _requestPhysicalExam),
          ),
          // Laboratory
          IconButton(
            icon: const Icon(Icons.science, color: Colors.white),
            tooltip: 'Laboratuvar',
            onPressed: _isChatClosed
                ? null
                : () => _showDataDialog(
                    'Laboratuvar Sonuçları',
                    _requestLaboratory,
                  ),
          ),
          // Imaging
          IconButton(
            icon: const Icon(
              Icons.enhance_photo_translate_rounded,
              color: Colors.white,
            ),
            tooltip: 'Görüntüleme',
            onPressed: _isChatClosed
                ? null
                : () =>
                      _showDataDialog('Görüntüleme Sonuçları', _requestImaging),
          ),
        ],
      ),
      body: Column(
        children: [
          // Teşhis ve Kaynağa bak butonları
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Sol taraf - Hasta bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_patientName != null)
                        Text(
                          _patientName!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 80, 125, 140),
                          ),
                        ),
                      if (_patientAge != null)
                        Text(
                          'Yaş: $_patientAge',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 80, 125, 140),
                          ),
                        ),
                    ],
                  ),
                ),
                // Sağ taraf - Butonlar
                Row(
                  children: [
                    // Teşhis butonu
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.view_kanban_outlined,
                            color: _isDiagnosisSubmitted
                                ? Colors.grey
                                : Color.fromARGB(255, 80, 125, 140),
                          ),
                          tooltip: 'Teşhis Gönder',
                          onPressed: _isDiagnosisSubmitted || _isChatClosed
                              ? null
                              : () => _showDiagnoseDialog(),
                        ),
                        const Text(
                          'Teşhisi gir',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color.fromARGB(255, 80, 125, 140),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Kaynağa bak butonu
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.menu_book_outlined,
                            color:
                                _isDiagnosisSubmitted &&
                                    _isChatClosed &&
                                    _correctDiagnosis != null
                                ? const Color.fromARGB(255, 248, 82, 31)
                                : Colors.grey,
                          ),
                          tooltip: 'Kaynağa Bak',
                          onPressed:
                              _isDiagnosisSubmitted &&
                                  _isChatClosed &&
                                  _correctDiagnosis != null
                              ? () => _goToSourcePage()
                              : null,
                        ),
                        const Text(
                          'Kaynağa bak',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color.fromARGB(255, 80, 125, 140),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 80, 125, 140),
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return Align(
                        alignment: message['sender'] == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: EdgeInsets.only(
                            top: 6,
                            bottom: 6,
                            left: message['sender'] == 'user' ? 60 : 12,
                            right: message['sender'] == 'user' ? 12 : 60,
                          ),
                          decoration: BoxDecoration(
                            color: message['sender'] == 'user'
                                ? Color.fromARGB(255, 80, 125, 140)
                                : Color.fromARGB(117, 179, 222, 236),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: message['sender'] == 'user'
                                  ? Colors.white
                                  : const Color.fromARGB(255, 2, 2, 2),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Diagnose mesajı kutusu
          if (_diagnosisMessage != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(
                  color: _isCorrect == true
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _isCorrect == true
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _diagnosisMessage!,
                      style: TextStyle(
                        color: _isCorrect == true
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Chat input alanı
          if (!_isChatClosed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isChatClosed,
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 80, 125, 140),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isChatClosed
                          ? Colors.grey
                          : Color.fromARGB(255, 80, 125, 140),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isChatClosed ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isChatClosed) return;

    final userMessage = _messageController.text;
    if (mounted) {
      setState(() {
        _messages.add({'sender': 'user', 'text': userMessage});
      });
    }
    _messageController.clear();

    // API'ye chat isteği gönder
    try {
      if (_sessionId == null) {
        if (mounted) {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text': 'Session başlatılamadı. Lütfen tekrar deneyin.',
            });
          });
        }
        return;
      }

      final response = await ApiService.sendChatMessage(
        message: userMessage,
        sessionId: _sessionId!,
        userGender: widget.doctorGender ?? 'Erkek',
      );

      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': response});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Mesaj gönderilemedi. Lütfen tekrar deneyin.',
          });
        });
      }
    }
  }

  void _showDataDialog(
    String title,
    Future<Map<String, dynamic>?> Function() dataFunction,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: dataFunction(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 80, 125, 140),
                      ),
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Dialog(
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Expanded(
                        child: Center(child: Text('Veri alınamadı')),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(child: _buildDataList(data)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataList(Map<String, dynamic> data, {int indent = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        if (entry.value is Map<String, dynamic>) {
          // Nested map için - ilk key'i gösterme
          return _buildDataList(
            entry.value as Map<String, dynamic>,
            indent: indent,
          );
        } else if (entry.value is Map) {
          // Diğer map türleri için - ilk key'i gösterme
          final mapVal = Map<String, dynamic>.from(entry.value as Map);
          return _buildDataList(mapVal, indent: indent);
        } else {
          return Padding(
            padding: EdgeInsets.only(left: indent.toDouble()),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 125,
                  child: Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 80, 125, 140),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(color: Color(0xFF414A4C)),
                  ),
                ),
              ],
            ),
          );
        }
      }).toList(),
    );
  }

  Future<Map<String, dynamic>?> _requestVitalSigns() async {
    try {
      final response = await ApiService.getVitalSigns();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _requestPhysicalExam() async {
    try {
      final response = await ApiService.getPhysicalExam();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _requestLaboratory() async {
    try {
      final response = await ApiService.getLaboratory();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _requestImaging() async {
    try {
      final response = await ApiService.getImaging();
      return response;
    } catch (e) {
      return null;
    }
  }

  void _showDiagnoseDialog() {
    final TextEditingController diagnoseController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Teşhis Gönder'),
          content: TextField(
            controller: diagnoseController,
            decoration: const InputDecoration(
              hintText: 'Teşhisinizi yazın...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final diagnosis = diagnoseController.text.trim();
                if (diagnosis.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _submitDiagnosis(diagnosis);
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitDiagnosis(String diagnosis) async {
    if (mounted) {
      setState(() {
        _messages.add({'sender': 'user', 'text': 'Teşhis: $diagnosis'});
        _isDiagnosisSubmitted = true;
      });
    }

    try {
      final response = await ApiService.submitDiagnosis(
        diagnosis: diagnosis,
        message: diagnosis,
      );

      if (response != null && response['message'] != null) {
        if (mounted) {
          setState(() {
            _diagnosisMessage = response['message'];
            _isCorrect = response['is_correct'] ?? false;
            _isChatClosed = true;
          });
        }

        // Hasta bilgilerini al ve sohbeti kaydet
        await _getPatientInfoAndSaveChat();
      } else {
        if (mounted) {
          setState(() {
            _diagnosisMessage = 'Teşhis gönderilemedi.';
            _isChatClosed = true;
          });
        }
        await _getPatientInfoAndSaveChat();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _diagnosisMessage = 'Teşhis gönderilirken hata oluştu.';
          _isChatClosed = true;
        });
      }
      await _getPatientInfoAndSaveChat();
    }
  }

  Future<void> _getPatientInfo() async {
    try {
      if (_sessionId != null) {
        final patientInfo = await ApiService.getPatientInfo(_sessionId!);
        print('Patient Info Debug: $patientInfo');
        if (patientInfo != null &&
            (patientInfo['name'] != null ||
                patientInfo['patient_name'] != null)) {
          if (mounted) {
            setState(() {
              _patientName = patientInfo['patient_name'] ?? patientInfo['name'];
              _patientAge = patientInfo['patient_age'];
              _correctDiagnosis = patientInfo['correct_diagnosis'];
              print('Correct Diagnosis set: $_correctDiagnosis');
            });
          }
        }
      }
    } catch (e) {
      print('Patient Info Error: $e');
      // Hata durumunda sessizce devam et
    }
  }

  Future<void> _getPatientInfoAndSaveChat() async {
    try {
      if (_sessionId != null) {
        final patientInfo = await ApiService.getPatientInfo(_sessionId!);
        if (patientInfo != null &&
            (patientInfo['name'] != null ||
                patientInfo['patient_name'] != null)) {
          _patientName = patientInfo['patient_name'] ?? patientInfo['name'];
          _patientAge = patientInfo['patient_age'];
          _correctDiagnosis = patientInfo['correct_diagnosis'];

          // Sohbeti kaydet
          await _saveChatToHistory();
        } else {
          // Yine de sohbeti kaydet
          await _saveChatToHistory();
        }
      } else {
        // Yine de sohbeti kaydet
        await _saveChatToHistory();
      }
    } catch (e) {
      // Hata durumunda da sohbeti kaydet
      await _saveChatToHistory();
    }
  }

  Future<void> _saveChatToHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await AuthService.getCurrentUser();
      final userKey = currentUser?.username ?? 'anonymous';
      final chatHistoryKey = 'chat_history_$userKey';

      final chatHistory = prefs.getStringList(chatHistoryKey) ?? [];

      final chatData = {
        'sessionId': _sessionId,
        'patientName': _patientName,
        'patientAge': _patientAge,
        'area': widget.area,
        'doctorGender': widget.doctorGender,
        'messages': _messages,
        'diagnosisMessage': _diagnosisMessage,
        'is_correct': _isCorrect,
        'correctDiagnosis': _correctDiagnosis,
        'timestamp': DateTime.now().toIso8601String(),
      };

      chatHistory.add(jsonEncode(chatData));
      await prefs.setStringList(chatHistoryKey, chatHistory);
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  void _goToSourcePage() {
    if (_correctDiagnosis != null && widget.area != null) {
      final uri = Uri(
        path: '/source',
        queryParameters: {
          'area': widget.area,
          'correct_diagnosis': _correctDiagnosis,
        },
      );
      context.push(uri.toString());
    } else {
      // Eğer gerekli bilgiler yoksa kullanıcıya bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaynak bilgileri için gerekli veriler eksik'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
