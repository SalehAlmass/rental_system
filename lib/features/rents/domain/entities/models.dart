class RentItem {
  const RentItem({
    required this.id,
    required this.rentId,
    required this.equipmentId,
    this.rate,
    this.notes,
    this.status,
    this.startDatetime,
    this.endDatetime,
    this.replacedById,
    this.equipmentName,
    this.serialNo,
    this.internalCode,
    this.parsedStartDatetime,
    this.parsedEndDatetime,
  });

  final int id;
  final int rentId;
  final int equipmentId;
  final double? rate;
  final String? notes;
  final String? status;
  final String? startDatetime;
  final String? endDatetime;
  final int? replacedById;
  final String? equipmentName;
  final String? serialNo;
  final String? internalCode;
  final DateTime? parsedStartDatetime;
  final DateTime? parsedEndDatetime;

  factory RentItem.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    double? toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    final startStr = json['start_datetime']?.toString();
    final endStr = json['end_datetime']?.toString();

    return RentItem(
      id: toInt(json['id']),
      rentId: toInt(json['rent_id']),
      equipmentId: toInt(json['equipment_id']),
      rate: toDouble(json['rate']),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      startDatetime: startStr,
      endDatetime: endStr,
      replacedById: json['replaced_by_id'] == null ? null : toInt(json['replaced_by_id']),
      equipmentName: json['equipment_name']?.toString(),
      serialNo: json['serial_no']?.toString(),
      internalCode: json['internal_code']?.toString(),
      parsedStartDatetime: startStr != null ? DateTime.tryParse(startStr.replaceFirst(' ', 'T')) : null,
      parsedEndDatetime: endStr != null ? DateTime.tryParse(endStr.replaceFirst(' ', 'T')) : null,
    );
  }
}

class Rent {
  const Rent({
    required this.id,
    required this.clientId,
    required this.equipmentId,
    required this.startDatetime,
    this.items = const [],
    this.endDatetime,
    this.hours,
    this.rate,
    this.totalAmount,
    this.notes,
    this.status,
    this.clientName,
    this.clientPhone,
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
    this.discountAmount,
    this.discountNote,
    this.parsedStartDatetime,
    this.parsedEndDatetime,
  });

  final int id;
  final int clientId;
  final int equipmentId;

  final String startDatetime;
  final List<RentItem> items;
  final String? endDatetime;

  final double? hours;
  final double? rate;
  final double? totalAmount;

  final String? notes;
  final String? status;

  final String? clientName;
  final String? clientPhone;
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
  final double? discountAmount;
  final String? discountNote;
  final DateTime? parsedStartDatetime;
  final DateTime? parsedEndDatetime;

  /* =========================
     JSON
  ========================= */

  factory Rent.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    double? toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    final startStr = json['start_datetime']?.toString() ?? '';
    final endStr = json['end_datetime']?.toString();

    return Rent(
      id: toInt(json['id']),
      clientId: toInt(json['client_id']),
      equipmentId: toInt(json['equipment_id']),
      startDatetime: startStr,
      items: json['items'] != null
          ? (json['items'] as List).map((e) => RentItem.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      endDatetime: endStr,
      hours: toDouble(json['hours']),
      rate: toDouble(json['rate']),
      totalAmount: toDouble(json['total_amount']),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      clientName: json['client_name']?.toString(),
      clientPhone: json['client_phone']?.toString(),
      equipmentName: json['equipment_name']?.toString(),
      closedAt: json['closed_at']?.toString(),
      closedByUserId: json['closed_by_user_id'] == null ? null : toInt(json['closed_by_user_id']),
      closingPaidAmount: toDouble(json['closing_paid_amount']),
      closingPaymentMethod: json['closing_payment_method']?.toString(),
      closingPaymentStatus: json['closing_payment_status']?.toString(),
      closingPaymentId: json['closing_payment_id'] == null ? null : toInt(json['closing_payment_id']),
      pricingRuleCode: json['pricing_rule_code']?.toString(),
      pricingRuleLabel: json['pricing_rule_label']?.toString(),
      pricingRuleApplied: json['pricing_rule_applied'] == null ? null : (toInt(json['pricing_rule_applied']) == 1),
      paidAmount: toDouble(json['paid_amount']),
      remainingAmount: toDouble(json['remaining_amount'] ?? json['remaining']),
      isPaid: json['is_paid'] == null ? null : (toInt(json['is_paid']) == 1 || json['is_paid'] == true),
      discountAmount: toDouble(json['discount_amount']),
      discountNote: json['discount_note']?.toString(),
      parsedStartDatetime: DateTime.tryParse(startStr.replaceFirst(' ', 'T')),
      parsedEndDatetime: endStr != null ? DateTime.tryParse(endStr.replaceFirst(' ', 'T')) : null,
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
    List<RentItem>? items,
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
    double? discountAmount,
    String? discountNote,
  }) {
    return Rent(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      equipmentId: equipmentId ?? this.equipmentId,
      startDatetime: startDatetime ?? this.startDatetime,
      items: items ?? this.items,
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
      discountAmount: discountAmount ?? this.discountAmount,
      discountNote: discountNote ?? this.discountNote,
      parsedStartDatetime: startDatetime != null
          ? DateTime.tryParse(startDatetime.replaceFirst(' ', 'T'))
          : this.parsedStartDatetime,
      parsedEndDatetime: endDatetime != null
          ? DateTime.tryParse(endDatetime.replaceFirst(' ', 'T'))
          : this.parsedEndDatetime,
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
      case 'promise_to_pay':
      case 'promised_to_pay':
        return 'وعد بالسداد';
      case 'paid':
        return 'تم التحصيل';
      case 'no_answer':
        return 'لا يرد';
      case 'not_responding':
        return 'لا يرد / لا يستجيب';
      case 'disputed':
        return 'يعترض على المبلغ';
      case 'follow_up_later':
      case 'followup_scheduled':
        return 'متابعة لاحقة';
      case 'customer_requested_delay':
        return 'تأجيل بطلب العميل';
      case 'other':
        return 'أخرى';
      default:
        return outcome.isEmpty ? '-' : outcome;
    }
  }
}
