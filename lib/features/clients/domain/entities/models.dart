class Client {
  Client({
    required this.id,
    required this.name,
    this.nationalId,
    this.phone,
    this.address,
    this.isFrozen = 0,
    this.creditLimit = 0,
  });

  final int id;
  final String name;
  final String? nationalId;
  final String? phone;
  final String? address;
  final int isFrozen;
  final double creditLimit;

  // 🔹 Helpers آمنة للتحويل
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String? _toNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      nationalId: _toNullableString(json['national_id']),
      phone: _toNullableString(json['phone']),
      address: _toNullableString(json['address']),
      isFrozen: _toInt(json['is_frozen']),
      creditLimit: _toDouble(json['credit_limit']),
    );
  }
}
