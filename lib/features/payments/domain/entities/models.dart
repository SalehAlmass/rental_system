class Payment {
  const Payment({
    required this.id,
    required this.type,
    required this.amount,
    this.clientId,
    this.rentId,
    this.method,
    this.referenceNo,
    this.notes,
    this.isVoid = false,
    this.voidedAt,
    this.voidReason,
    this.clientName,
    this.rentNo,
    this.createdAt,
  });

  final int id;
  final String type; // in|out
  final double amount;
  final int? clientId;
  final int? rentId;
  final String? method;
  final String? referenceNo;
  final String? notes;
  final bool isVoid;
  final String? voidedAt;
  final String? voidReason;
  final String? clientName;
  final int? rentNo;
  final String? createdAt;

  factory Payment.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    int? toINull(dynamic v) {
      if (v == null) return null;
      final i = toI(v);
      return i == 0 ? null : i;
    }

    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    bool toB(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      final s = v.toString();
      return s != '0' && s.toLowerCase() != 'false';
    }

    return Payment(
      id: toI(json['id']),
      type: (json['type'] ?? '').toString(),
      amount: toD(json['amount']),
      clientId: toINull(json['client_id']),
      rentId: toINull(json['rent_id']),
      method: json['method']?.toString(),
      referenceNo: json['reference_no']?.toString(),
      notes: json['notes']?.toString(),
      isVoid: toB(json['is_void']),
      voidedAt: json['voided_at']?.toString(),
      voidReason: json['void_reason']?.toString(),
      clientName: json['client_name']?.toString(),
      rentNo: toINull(json['rent_no']),
      createdAt: json['created_at']?.toString(),
    );
  }
}
