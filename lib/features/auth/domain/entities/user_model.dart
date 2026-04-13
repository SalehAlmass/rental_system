class User {
  final int id;
  final String username;
  final String role;
  final DateTime createdAt;
  final bool isActive;
  final Map<String, dynamic> permissions;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.permissions = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    return User(
      id: int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      role: json['role'] ?? 'employee',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      permissions: rawPermissions is Map ? rawPermissions.cast<String, dynamic>() : const {},
    );
  }

  String get contractHourPricingMode => (permissions['contract_hour_pricing_mode'] ?? 'inherit').toString();
  String get contractPaymentReceiptMode => (permissions['contract_payment_receipt_mode'] ?? 'inherit').toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'permissions': permissions,
    };
  }
}
