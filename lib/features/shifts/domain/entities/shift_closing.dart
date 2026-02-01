class ShiftClosing {
  const ShiftClosing({
    required this.id,
    required this.userId,
    required this.shiftDate,
    required this.expectedAmount,
    required this.actualAmount,
    required this.difference,
    this.notes,
    this.username,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String shiftDate; // YYYY-MM-DD
  final double expectedAmount;
  final double actualAmount;
  final double difference;
  final String? notes;
  final String? username;
  final String? createdAt;

  factory ShiftClosing.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    double toD(dynamic v) => v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    return ShiftClosing(
      id: toI(json['id']),
      userId: toI(json['user_id']),
      username: json['username']?.toString(),
      shiftDate: (json['shift_date'] ?? '').toString(),
      expectedAmount: toD(json['expected_amount']),
      actualAmount: toD(json['actual_amount']),
      difference: toD(json['difference']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
