part of 'payments_bloc.dart';

enum PaymentsStatus { initial, loading, success, failure }

class PaymentsState extends Equatable {
  const PaymentsState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
    this.showVoided = false,
  });

  const PaymentsState.initial()
      : status = PaymentsStatus.initial,
        items = const [],
        error = null,
        working = false,
        showVoided = false;

  final PaymentsStatus status;
  final List<Payment> items;
  final String? error;
  final bool working;
  final bool showVoided;

  PaymentsState copyWith({
    PaymentsStatus? status,
    List<Payment>? items,
    String? error,
    bool? working,
    bool? showVoided,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
      showVoided: showVoided ?? this.showVoided,
    );
  }

  @override
  List<Object?> get props => [status, items, error, working, showVoided];
}
