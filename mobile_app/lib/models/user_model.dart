class User {
  final String username;
  final String password;
  final String gender;
  final DateTime createdAt;

  User({
    required this.username,
    required this.password,
    required this.gender,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'gender': gender,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      password: json['password'],
      gender: json['gender'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
} 