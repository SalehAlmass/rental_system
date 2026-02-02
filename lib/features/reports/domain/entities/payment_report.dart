double parseDouble(dynamic value, {double defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? defaultValue;
}

int parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? defaultValue;
}

class PaymentReportTotals {
  final double totalIn;
  final double totalOut;
  final double net;

  const PaymentReportTotals({
    required this.totalIn,
    required this.totalOut,
    required this.net,
  });

  factory PaymentReportTotals.fromJson(Map<String, dynamic> json) {
    return PaymentReportTotals(
      totalIn: parseDouble(json['in']),
      totalOut: parseDouble(json['out']),
      net: parseDouble(json['net']),
    );
  }
}
class PaymentReportRow {
  final int id;
  final String createdAt;
  final String type; // in | out
  final double amount;
  final String? method;
  final String? clientName;
  final int? rentNo;
  final String? referenceNo;
  final String? notes;

  const PaymentReportRow({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.amount,
    this.method,
    this.clientName,
    this.rentNo,
    this.referenceNo,
    this.notes,
  });

  factory PaymentReportRow.fromJson(Map<String, dynamic> json) {
    return PaymentReportRow(
      id: parseInt(json['id']),
      createdAt: json['created_at']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: parseDouble(json['amount']),
      method: json['method']?.toString(),
      clientName: json['client_name']?.toString(),
      rentNo: json['rent_no'] == null ? null : parseInt(json['rent_no']),
      referenceNo: json['reference_no']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}
class PaymentsReport {
  final String? from;
  final String? to;
  final String type; // in | out | all
  final PaymentReportTotals totals;
  final List<PaymentReportRow> rows;

  const PaymentsReport({
    required this.from,
    required this.to,
    required this.type,
    required this.totals,
    required this.rows,
  });

  factory PaymentsReport.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PaymentReportRow.fromJson(
              e.cast<String, dynamic>(),
            ))
        .toList();

    return PaymentsReport(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      type: json['type']?.toString() ?? 'all',
      totals: PaymentReportTotals.fromJson(
        (json['totals'] as Map? ?? {}).cast<String, dynamic>(),
      ),
      rows: rows,
    );
  }
}
