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

  /* =========================
     JSON
  ========================= */

  factory Rent.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    double? _toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    return Rent(
      id: _toInt(json['id']),
      clientId: _toInt(json['client_id']),
      equipmentId: _toInt(json['equipment_id']),
      startDatetime: json['start_datetime']?.toString() ?? '',
      endDatetime: json['end_datetime']?.toString(),
      hours: _toDouble(json['hours']),
      rate: _toDouble(json['rate']),
      totalAmount: _toDouble(json['total_amount']),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      clientName: json['client_name']?.toString(),
      equipmentName: json['equipment_name']?.toString(),
    );
  }

  /* =========================
     COPY WITH
  ========================= */

  Rent copyWith({
    int? id,
    int? clientId,
    int? equipmentId,
    String? startDatetime,
    String? endDatetime,
    double? hours,
    double? rate,
    double? totalAmount,
    String? notes,
    String? status,
    String? clientName,
    String? equipmentName,
  }) {
    return Rent(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      equipmentId: equipmentId ?? this.equipmentId,
      startDatetime: startDatetime ?? this.startDatetime,
      endDatetime: endDatetime ?? this.endDatetime,
      hours: hours ?? this.hours,
      rate: rate ?? this.rate,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      equipmentName: equipmentName ?? this.equipmentName,
    );
  }
}
