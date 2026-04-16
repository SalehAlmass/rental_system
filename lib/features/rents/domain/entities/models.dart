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
    this.closedAt,
    this.closedByUserId,
    this.closingPaidAmount,
    this.closingPaymentMethod,
    this.closingPaymentStatus,
    this.closingPaymentId,
    this.pricingRuleCode,
    this.pricingRuleLabel,
    this.pricingRuleApplied,
    this.paidAmount,
    this.remainingAmount,
    this.isPaid,
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
  final String? closedAt;
  final int? closedByUserId;
  final double? closingPaidAmount;
  final String? closingPaymentMethod;
  final String? closingPaymentStatus;
  final int? closingPaymentId;
  final String? pricingRuleCode;
  final String? pricingRuleLabel;
  final bool? pricingRuleApplied;
  final double? paidAmount;
  final double? remainingAmount;
  final bool? isPaid;

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
      closedAt: json['closed_at']?.toString(),
      closedByUserId: json['closed_by_user_id'] == null ? null : _toInt(json['closed_by_user_id']),
      closingPaidAmount: _toDouble(json['closing_paid_amount']),
      closingPaymentMethod: json['closing_payment_method']?.toString(),
      closingPaymentStatus: json['closing_payment_status']?.toString(),
      closingPaymentId: json['closing_payment_id'] == null ? null : _toInt(json['closing_payment_id']),
      pricingRuleCode: json['pricing_rule_code']?.toString(),
      pricingRuleLabel: json['pricing_rule_label']?.toString(),
      pricingRuleApplied: json['pricing_rule_applied'] == null ? null : (_toInt(json['pricing_rule_applied']) == 1),
      paidAmount: _toDouble(json['paid_amount']),
      remainingAmount: _toDouble(json['remaining_amount'] ?? json['remaining']),
      isPaid: json['is_paid'] == null ? null : (_toInt(json['is_paid']) == 1 || json['is_paid'] == true),
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
    String? closedAt,
    int? closedByUserId,
    double? closingPaidAmount,
    String? closingPaymentMethod,
    String? closingPaymentStatus,
    int? closingPaymentId,
    String? pricingRuleCode,
    String? pricingRuleLabel,
    bool? pricingRuleApplied,
    double? paidAmount,
    double? remainingAmount,
    bool? isPaid,
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
      closedAt: closedAt ?? this.closedAt,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closingPaidAmount: closingPaidAmount ?? this.closingPaidAmount,
      closingPaymentMethod: closingPaymentMethod ?? this.closingPaymentMethod,
      closingPaymentStatus: closingPaymentStatus ?? this.closingPaymentStatus,
      closingPaymentId: closingPaymentId ?? this.closingPaymentId,
      pricingRuleCode: pricingRuleCode ?? this.pricingRuleCode,
      pricingRuleLabel: pricingRuleLabel ?? this.pricingRuleLabel,
      pricingRuleApplied: pricingRuleApplied ?? this.pricingRuleApplied,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

class CollectionFollowup {
  const CollectionFollowup({
    required this.id,
    required this.contactType,
    required this.outcome,
    required this.createdAt,
    this.note,
    this.nextFollowupAt,
    this.createdByUserId,
    this.createdByName,
  });

  final int id;
  final String contactType;
  final String outcome;
  final String createdAt;
  final String? note;
  final String? nextFollowupAt;
  final int? createdByUserId;
  final String? createdByName;

  factory CollectionFollowup.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return CollectionFollowup(
      id: toI(json['id']),
      contactType: (json['contact_type'] ?? '').toString(),
      outcome: (json['outcome'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      note: json['note']?.toString(),
      nextFollowupAt: json['next_followup_at']?.toString(),
      createdByUserId: json['created_by_user_id'] == null ? null : toI(json['created_by_user_id']),
      createdByName: json['created_by_name']?.toString(),
    );
  }

  String get contactTypeLabel {
    switch (contactType.toLowerCase()) {
      case 'call':
        return 'اتصال';
      case 'whatsapp':
        return 'واتساب';
      case 'visit':
        return 'زيارة';
      case 'verbal':
        return 'تذكير شفهي';
      case 'no_answer':
        return 'لم يتم الرد';
      default:
        return contactType.isEmpty ? '-' : contactType;
    }
  }

  String get outcomeLabel {
    switch (outcome.toLowerCase()) {
      case 'promised_to_pay':
        return 'وعد بالدفع';
      case 'paid':
        return 'تم الدفع';
      case 'not_responding':
        return 'لا يستجيب';
      case 'disputed':
        return 'يعترض على المبلغ';
      case 'followup_scheduled':
        return 'تم تحديد متابعة لاحقة';
      default:
        return outcome.isEmpty ? '-' : outcome;
    }
  }
}
