class SessionManager {
  static String? _sessionId;

  static void setSessionId(String id) {
    _sessionId = id;
  }

  static String? getSessionId() {
    return _sessionId;
  }

  static void clear() {
    _sessionId = null;
  }
}
