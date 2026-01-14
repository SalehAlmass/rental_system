class Rent {
  const Rent({
    required this.id,
    required this.clientId,
    required this.equipmentId,
    required this.startDatetime,
    this.endDatetime,
    this.hours,
    this.rate,
    this.totalAmount,
    this.notes,
    this.status,
    this.clientName,
    this.equipmentName,
  });

  final int id;
  final int clientId;
  final int equipmentId;
  final String startDatetime;
  final String? endDatetime;
  final double? hours;
  final double? rate;
  final double? totalAmount;
  final String? notes;
  final String? status;
  final String? clientName;
  final String? equipmentName;

  factory Rent.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    double? toDNullable(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Rent(
      id: toI(json['id']),
      clientId: toI(json['client_id']),
      equipmentId: toI(json['equipment_id']),
      startDatetime: (json['start_datetime'] ?? '').toString(),
      endDatetime: json['end_datetime']?.toString(),
      hours: toDNullable(json['hours']),
      rate: toDNullable(json['rate']),
      totalAmount: toDNullable(json['total_amount']),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      clientName: json['client_name']?.toString(),
      equipmentName: json['equipment_name']?.toString(),
    );
  }
}
