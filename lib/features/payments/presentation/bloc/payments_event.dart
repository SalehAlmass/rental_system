part of 'payments_bloc.dart';

sealed class PaymentsEvent extends Equatable {
  const PaymentsEvent();
  @override
  List<Object?> get props => [];
}

class PaymentsRequested extends PaymentsEvent {
  const PaymentsRequested({
    this.showVoided = false,
    this.query,
    this.page,
    this.perPage,
    this.sortBy,
    this.sortOrder,
  });
  final bool showVoided;
  final String? query;
  final int? page;
  final int? perPage;
  final String? sortBy;
  final String? sortOrder;
  @override
  List<Object?> get props => [showVoided, query, page, perPage, sortBy, sortOrder];
}

class PaymentCreated extends PaymentsEvent {
  const PaymentCreated({
    required this.type,
    required this.amount,
    this.clientId,
    this.rentId,
    this.equipmentId,
    this.method = 'cash',
    this.referenceNo,
    this.notes,
  });

  final String type;
  final double amount;
  final int? clientId;
  final int? rentId;
  final int? equipmentId;
  final String method;
  final String? referenceNo;
  final String? notes;

  @override
  List<Object?> get props => [
    type,
    amount,
    clientId,
    rentId,
    equipmentId,
    method,
    referenceNo,
    notes,
  ];
}

class PaymentUpdated extends PaymentsEvent {
  const PaymentUpdated({
    required this.id,
    required this.amount,
    this.clientId,
    this.rentId,
    this.equipmentId,
    this.method = 'cash',
    this.referenceNo,
    this.notes,
  });

  final int id;
  final double amount;
  final int? clientId;
  final int? rentId;
  final int? equipmentId;
  final String method;
  final String? referenceNo;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    amount,
    clientId,
    rentId,
    equipmentId,
    method,
    referenceNo,
    notes,
  ];
}

class PaymentVoided extends PaymentsEvent {
  const PaymentVoided({required this.id, this.reason});
  final int id;
  final String? reason;
  @override
  List<Object?> get props => [id, reason];
}
