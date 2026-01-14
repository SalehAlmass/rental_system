class LoginResponse {
  LoginResponse({required this.token, required this.user});
  final String token;
  final Map<String, dynamic> user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: (json['token'] ?? '') as String,
      user: (json['user'] ?? {}) as Map<String, dynamic>,
    );
  }
}
