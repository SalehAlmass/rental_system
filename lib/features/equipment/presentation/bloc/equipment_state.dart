part of 'equipment_bloc.dart';

enum EquipmentStatus { initial, loading, success, failure }

class EquipmentState extends Equatable {
  const EquipmentState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
    this.sortBy,
    this.sortOrder,
    this.query,
    this.filterStatus,
  });

  const EquipmentState.initial()
      : status = EquipmentStatus.initial,
        items = const [],
        error = null,
        working = false,
        sortBy = null,
        sortOrder = null,
        query = null,
        filterStatus = null;

  final EquipmentStatus status;
  final List<Equipment> items;
  final String? error;
  final bool working;
  final String? sortBy;
  final String? sortOrder;
  final String? query;
  final String? filterStatus;

  EquipmentState copyWith({
    EquipmentStatus? status,
    List<Equipment>? items,
    String? error,
    bool? working,
    String? sortBy,
    String? sortOrder,
    String? query,
    String? filterStatus,
  }) {
    return EquipmentState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      query: query ?? this.query,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }

  @override
  List<Object?> get props => [status, items, error, working, sortBy, sortOrder, query, filterStatus];
}
