class User {
  final int id;
  final String username;
  final String role;
  final DateTime createdAt;
  final bool isActive;
  final Map<String, dynamic> permissions;
  final Map<String, bool> screenPermissions;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.permissions = const {},
    this.screenPermissions = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final Map<String, dynamic> parsedPermissions = rawPermissions is Map
        ? rawPermissions.cast<String, dynamic>()
        : const {};

    final rawScreenPerms = json['screen_permissions'] ?? parsedPermissions['screen_permissions'];
    final Map<String, bool> screenPerms = {};
    if (rawScreenPerms is Map) {
      rawScreenPerms.forEach((k, v) {
        screenPerms[k.toString()] = v == true || v == 1 || v.toString() == 'true';
      });
    }

    return User(
      id: int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      role: json['role'] ?? 'employee',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      permissions: parsedPermissions,
      screenPermissions: screenPerms,
    );
  }

  String get contractHourPricingMode => (permissions['contract_hour_pricing_mode'] ?? 'inherit').toString();
  String get contractPaymentReceiptMode => (permissions['contract_payment_receipt_mode'] ?? 'inherit').toString();

  bool hasScreenPermission(String key) {
    if (role == 'admin') return true;
    return screenPermissions[key] == true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'permissions': permissions,
      'screen_permissions': screenPermissions,
    };
  }
}
