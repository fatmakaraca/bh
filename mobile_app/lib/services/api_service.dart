import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';

class ApiService {
  static const String baseUrl = 'https://bh-0n6v.onrender.com';

  // API endpoint'leri
  static const String selectAreaEndpoint = '/select_area';
  static const String chatEndpoint = '/chat';
  static const String resetEndpoint = '/reset';
  static const String statusEndpoint = '/status'; //health_check
  static const String diagnoseEndpoint = '/diagnose';
  static const String patientInfoEndpoint = '/patient_info';
  static const String labVitalSignsEndpoint = '/lab/vital_signs';
  static const String labPhysicalExamEndpoint = '/lab/physical_exam';
  static const String labLaboratoryEndpoint = '/lab/laboratory';
  static const String labImagingEndpoint = '/lab/imaging';
  static const String queryEndpoint = '/query';
  // Alternatif endpoint'ler
  static const String queryEndpoint2 = '/api/query';
  static const String queryEndpoint3 = '/v1/query';

  // Select Area endpoint
  static Future<Map<String, dynamic>?> selectArea({
    required String doctor_gender,
    required String area,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$selectAreaEndpoint').replace(
        queryParameters: {
          'doctor_gender': doctor_gender.toLowerCase(),
          'area': area,
        },
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      final responseJson = json.decode(response.body);
      final sessionId = responseJson['session_id'];

      // Belleğe kaydet
      SessionManager.setSessionId(sessionId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'session_id': 'mock_session_${DateTime.now().millisecondsSinceEpoch}',
        'message': 'Alan seçimi başarılı',
        'patient_info': 'Mock hasta bilgileri',
      };
    }
  }

  // Chat endpoint
  static Future<String> sendChatMessage({
    required String message,
    required String sessionId,
    required String userGender,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$chatEndpoint');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json;charset=UTF-8',
          'Accept': 'application/json',

          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'message': message,
          'user_gender': userGender,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'Yanıt alınamadı';
      } else {
        return 'Bağlantı hatası oluştu';
      }
    } catch (e) {
      // Geçici mock yanıt
      return 'Mock API yanıtı: Mesajınız alındı. API bağlantısı kurulduğunda gerçek yanıt alacaksınız.';
    }
  }

  // Reset session endpoint
  static Future<bool> resetSession() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$resetEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Health check endpoint
  static Future<bool> healthCheck() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$statusEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Diagnose endpoint
  static Future<Map<String, dynamic>?> submitDiagnosis({
    required String diagnosis,
    required String message,
  }) async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse('$baseUrl$diagnoseEndpoint');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({
          'message': message,
          'diagnosis': diagnosis,
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Patient Info endpoint
  static Future<Map<String, dynamic>?> getPatientInfo(String sessionId) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$patientInfoEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'name': 'Mock Hasta Adı',
        'patient_age': '25',
        'correct_diagnosis': 'Mock Doğru Teşhis',
      };
    }
  }

  // Lab endpoints
  static Future<Map<String, dynamic>?> getVitalSigns() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$labVitalSignsEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'vital_signs': {
          'blood_pressure': '120/80 mmHg',
          'heart_rate': '72 bpm',
          'temperature': '36.8°C',
          'oxygen_saturation': '98%',
        },
      };
    }
  }

  static Future<Map<String, dynamic>?> getPhysicalExam() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$labPhysicalExamEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'physical_exam': {
          'skin': 'bilateral dirsek',
          'scalp': 'saçlı derde bir şeyler',
          'head': 'normal',
          'neck': 'normal',
        },
      };
    }
  }

  static Future<Map<String, dynamic>?> getLaboratory() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$labLaboratoryEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'laboratory': {
          'hemoglobin': '14.2 g/dL',
          'white_blood_cells': '7.5 x10^9/L',
          'platelets': '250 x10^9/L',
          'glucose': '95 mg/dL',
        },
      };
    }
  }

  static Future<Map<String, dynamic>?> getImaging() async {
    final sessionId = SessionManager.getSessionId();
    try {
      final uri = Uri.parse(
        '$baseUrl$labImagingEndpoint',
      ).replace(queryParameters: {'session_id': sessionId});
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return null;
      }
    } catch (e) {
      // Geçici mock data
      return {
        'imaging': {
          'chest_xray': 'normal',
          'abdominal_ultrasound': 'normal',
          'ct_scan': 'normal',
          'mri': 'normal',
        },
      };
    }
  }

    // Query endpoint
  static Future<Map<String, dynamic>?> sendQuery({
    required String question,
    required String speciality,
  }) async {
    // Farklı endpoint'leri dene
    final endpoints = [queryEndpoint, queryEndpoint2, queryEndpoint3];
    
    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse('$baseUrl$endpoint');
        
        print('Query API Debug (trying $endpoint):');
        print('URL: $uri');
        print('Question: $question');
        print('Speciality: $speciality');

        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          body: jsonEncode({
            'question': question,
            'specialty': speciality,
          }),
        ).timeout(
          const Duration(seconds: 30), // 30 saniye timeout
          onTimeout: () {
            print('Timeout for $endpoint');
            throw Exception('Request timeout');
          },
        );

        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Parsed Data: $data');
          
          // Farklı response formatlarını kontrol et
          if (data['answer'] != null) {
            return data;
          } else if (data['response'] != null) {
            return {'answer': data['response']};
          } else if (data['message'] != null) {
            return {'answer': data['message']};
          } else if (data['content'] != null) {
            return {'answer': data['content']};
          } else {
            // Response'u string olarak döndür
            return {'answer': response.body};
          }
        } else {
          print('Error Status Code: ${response.statusCode}');
          continue; // Sonraki endpoint'i dene
        }
      } catch (e) {
        print('Query API Error for $endpoint: $e');
        continue; // Sonraki endpoint'i dene
      }
    }
    
    // Hiçbir endpoint çalışmazsa mock data döndür
    print('All endpoints failed, returning mock data');
    return {
      'answer': 'Mock yanıt: Bu teşhis hakkında detaylı bilgi almak için kaynaklara bakabilirsiniz.',
    };
  }
}
