import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:btk_demo/models/user_model.dart';

class AuthService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';

  // Kullanıcı kaydetme
  static Future<bool> registerUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      
      // Kullanıcı adının zaten var olup olmadığını kontrol et
      for (String userJson in usersJson) {
        final existingUser = User.fromJson(jsonDecode(userJson));
        if (existingUser.username == user.username) {
          return false; // Kullanıcı adı zaten mevcut
        }
      }
      
      // Yeni kullanıcıyı ekle
      usersJson.add(jsonEncode(user.toJson()));
      await prefs.setStringList(_usersKey, usersJson);
      
      // Otomatik giriş yap
      await _setCurrentUser(user);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcı girişi
  static Future<bool> loginUser(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      
      for (String userJson in usersJson) {
        final user = User.fromJson(jsonDecode(userJson));
        if (user.username == username && user.password == password) {
          await _setCurrentUser(user);
          return true;
        }
      }
      
      return false; // Kullanıcı bulunamadı
    } catch (e) {
      return false;
    }
  }

  // Mevcut kullanıcıyı al
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      
      if (userJson != null) {
        final user = User.fromJson(jsonDecode(userJson));
        return user;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Çıkış yap
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Mevcut kullanıcıyı ayarla
  static Future<void> _setCurrentUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Kullanıcı adının mevcut olup olmadığını kontrol et
  static Future<bool> isUsernameTaken(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      
      for (String userJson in usersJson) {
        final user = User.fromJson(jsonDecode(userJson));
        if (user.username == username) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Debug: Tüm kullanıcıları listele
  static Future<void> debugListAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_usersKey) ?? [];
      final currentUserJson = prefs.getString(_currentUserKey);
      
      for (int i = 0; i < usersJson.length; i++) {
        final user = User.fromJson(jsonDecode(usersJson[i]));
      }
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }
} 