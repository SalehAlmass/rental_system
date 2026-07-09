part of 'rents_bloc.dart';

enum RentsStatus { initial, loading, success, failure }

class RentsState extends Equatable {
  const RentsState({
    required this.status,
    required this.items,
    this.filterStatus,
    this.error,
    this.working = false,
    this.currentPage = 1,
    this.totalCount = 0,
    this.perPage = 20,
    this.searchQuery = '',
  });

  const RentsState.initial()
      : status = RentsStatus.initial,
        items = const [],
        filterStatus = null,
        error = null,
        working = false,
        currentPage = 1,
        totalCount = 0,
        perPage = 20,
        searchQuery = '';

  final RentsStatus status;
  final List<Rent> items;
  /// open|closed|cancelled|null(all)
  final String? filterStatus;
  final String? error;
  final bool working;
  final int currentPage;
  final int totalCount;
  final int perPage;
  final String searchQuery;

  RentsState copyWith({
    RentsStatus? status,
    List<Rent>? items,
    String? filterStatus,
    String? error,
    bool? working,
    int? currentPage,
    int? totalCount,
    int? perPage,
    String? searchQuery,
  }) {
    return RentsState(
      status: status ?? this.status,
      items: items ?? this.items,
      filterStatus: filterStatus ?? this.filterStatus,
      error: error,
      working: working ?? this.working,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      perPage: perPage ?? this.perPage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        filterStatus,
        error,
        working,
        currentPage,
        totalCount,
        perPage,
        searchQuery,
      ];
}
