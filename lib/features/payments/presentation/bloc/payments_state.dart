part of 'payments_bloc.dart';

enum PaymentsStatus { initial, loading, success, failure }

class PaymentsState extends Equatable {
  const PaymentsState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
    this.showVoided = false,
    this.summary,
    this.total = 0,
  });

  const PaymentsState.initial()
      : status = PaymentsStatus.initial,
        items = const [],
        error = null,
        working = false,
        showVoided = false,
        summary = null,
        total = 0;

  final PaymentsStatus status;
  final List<Payment> items;
  final String? error;
  final bool working;
  final bool showVoided;
  final PaymentSummary? summary;
  final int total;

  PaymentsState copyWith({
    PaymentsStatus? status,
    List<Payment>? items,
    String? error,
    bool? working,
    bool? showVoided,
    PaymentSummary? summary,
    int? total,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
      showVoided: showVoided ?? this.showVoided,
      summary: summary ?? this.summary,
      total: total ?? this.total,
    );
  }

  @override
  List<Object?> get props =>
      [status, items, error, working, showVoided, summary, total];
}
