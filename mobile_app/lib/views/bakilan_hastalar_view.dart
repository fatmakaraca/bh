import 'dart:convert';
import 'package:btk_demo/services/api_service.dart';
import 'package:btk_demo/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class BakilanHastalarView extends StatefulWidget {
  const BakilanHastalarView({super.key});

  @override
  State<BakilanHastalarView> createState() => _BakilanHastalarViewState();
}

class _BakilanHastalarViewState extends State<BakilanHastalarView> {
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await AuthService.getCurrentUser();
      final userKey = currentUser?.username ?? 'anonymous';
      final chatHistoryKey = 'chat_history_$userKey';

      final chatHistoryStrings = prefs.getStringList(chatHistoryKey) ?? [];

      final List<Future<Map<String, dynamic>>> futures = [];

      for (final chatString in chatHistoryStrings) {
        futures.add(_enrichChatData(chatString));
      }

      final results = await Future.wait(futures);

      results.removeWhere((e) => e.isEmpty); // Geçersiz olanları çıkar

      results.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _chatHistory = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _enrichChatData(String chatString) async {
    try {
      final chatData = jsonDecode(chatString) as Map<String, dynamic>;
      final sessionId = chatData['sessionId'];

      if (sessionId != null) {
        final patientInfo = await ApiService.getPatientInfo(sessionId);
        if (patientInfo != null) {
          chatData['patientName'] =
              patientInfo['patient_name'] ??
              chatData['patientName'] ??
              'Bilinmeyen Hasta';
          chatData['patientAge'] =
              patientInfo['patient_age'] ?? chatData['patientAge'] ?? '';
          chatData['correctDiagnosis'] = patientInfo['correct_diagnosis'] ?? '';
        }
      }

      return chatData;
    } catch (_) {
      return {}; // Hatalıysa boş dön
    }
  }

  String _getAreaImage(String? area) {
    switch (area?.toLowerCase()) {
      case 'kardiyoloji':
        return 'assets/kardiyo2.png';
      case 'dermatoloji':
        return 'assets/dermo1.png';
      case 'endokrinoloji':
        return 'assets/endokrinoloji2.png';
      case 'enfeksiyon_hastalıkları':
        return 'assets/enfeksiyon.png';
      case 'gastroenteroloji':
        return 'assets/gastro1.png';
      case 'nefroloji':
        return 'assets/nefro1.png';
      case 'nöroloji':
        return 'assets/noroloji4.png';
      case 'pediatri':
        return 'assets/pedi.png';
      case 'pulmonoloji':
        return 'assets/pulmo2.png';
      case 'romatoloji':
        return 'assets/romato1.png';
      default:
        return 'assets/nurse_icon.png';
    }
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Bilinmeyen tarih';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Bakılan Hastalar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color.fromARGB(255, 80, 125, 140),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 80, 125, 140),
                ),
              ),
            )
          : _chatHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz hasta kaydı bulunmuyor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Geçmiş sohbetler burada görünecek',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadChatHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final chat = _chatHistory[index];
                  final patientName = chat['patientName'] ?? 'Bilinmeyen Hasta';
                  final patientAge = chat['patientAge'] ?? '';
                  final correctDiagnosis = chat['correctDiagnosis'] ?? '';
                  final area = chat['area'] ?? '';
                  final timestamp = chat['timestamp'] ?? '';
                  final isCorrect = chat['is_correct'] ?? false;
                  final messages =
                      (chat['messages'] as List<dynamic>?)
                          ?.map(
                            (msg) => Map<String, String>.from(
                              msg as Map<String, dynamic>,
                            ),
                          )
                          .toList() ??
                      [];
                  final diagnosisMessage = chat['diagnosisMessage'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage(_getAreaImage(area)),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (patientAge.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Yaş: $patientAge',
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                          if (correctDiagnosis.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              correctDiagnosis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: Color(0xFF414A4C),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            area,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(timestamp),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          if (diagnosisMessage.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCorrect == true
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Teşhis tamamlandı',
                                style: TextStyle(
                                  color: isCorrect == true
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      onTap: () => _showChatDetails(context, chat),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showChatDetails(BuildContext context, Map<String, dynamic> chat) {
    final patientName = chat['patientName'] ?? 'Bilinmeyen Hasta';
    final messages =
        (chat['messages'] as List<dynamic>?)
            ?.map(
              (msg) => Map<String, String>.from(msg as Map<String, dynamic>),
            )
            .toList() ??
        [];
    final diagnosisMessage = chat['diagnosisMessage'] ?? '';
    final isCorrect = chat['is_correct'] ?? false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Align(
                        alignment: message['sender'] == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: message['sender'] == 'user'
                                ? Color.fromARGB(255, 80, 125, 140)
                                : Colors.white,
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
                                  : const Color(0xFF414A4C),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (diagnosisMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCorrect == true
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      border: Border.all(
                        color: isCorrect == true
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isCorrect == true
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diagnosisMessage,
                            style: TextStyle(
                              color: isCorrect == true
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
              ],
            ),
          ),
        );
      },
    );
  }
}
