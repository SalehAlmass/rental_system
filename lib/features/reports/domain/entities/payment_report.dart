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
      totalIn: (json['in'] as num?)?.toDouble() ?? 0,
      totalOut: (json['out'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentReportRow {
  final int id;
  final String createdAt;
  final String type; // in|out
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
      id: (json['id'] as num).toInt(),
      createdAt: (json['created_at'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method']?.toString(),
      clientName: json['client_name']?.toString(),
      rentNo: (json['rent_no'] as num?)?.toInt(),
      referenceNo: json['reference_no']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class PaymentsReport {
  final String? from;
  final String? to;
  final String type; // in|out|all
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
        .map((e) => PaymentReportRow.fromJson(e.cast<String, dynamic>()))
        .toList();

    return PaymentsReport(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      type: (json['type'] ?? 'all').toString(),
      totals: PaymentReportTotals.fromJson(
        (json['totals'] as Map? ?? {}).cast<String, dynamic>(),
      ),
      rows: rows,
    );
  }
}
