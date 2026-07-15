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
    this.query,
    this.page = 1,
    this.perPage = 200,
    this.sortBy,
    this.sortOrder,
  });

  const PaymentsState.initial()
      : status = PaymentsStatus.initial,
        items = const [],
        error = null,
        working = false,
        showVoided = false,
        summary = null,
        total = 0,
        query = null,
        page = 1,
        perPage = 200,
        sortBy = null,
        sortOrder = null;

  final PaymentsStatus status;
  final List<Payment> items;
  final String? error;
  final bool working;
  final bool showVoided;
  final PaymentSummary? summary;
  final int total;
  final String? query;
  final int page;
  final int perPage;
  final String? sortBy;
  final String? sortOrder;

  PaymentsState copyWith({
    PaymentsStatus? status,
    List<Payment>? items,
    String? error,
    bool? working,
    bool? showVoided,
    PaymentSummary? summary,
    int? total,
    String? query,
    int? page,
    int? perPage,
    String? sortBy,
    String? sortOrder,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
      showVoided: showVoided ?? this.showVoided,
      summary: summary ?? this.summary,
      total: total ?? this.total,
      query: query ?? this.query,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props =>
      [status, items, error, working, showVoided, summary, total, query, page, perPage, sortBy, sortOrder];
}
