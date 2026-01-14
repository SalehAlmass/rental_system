part of 'equipment_bloc.dart';

enum EquipmentStatus { initial, loading, success, failure }

class EquipmentState extends Equatable {
  const EquipmentState({
    required this.status,
    required this.items,
    this.error,
    this.working = false,
  });

  const EquipmentState.initial()
      : status = EquipmentStatus.initial,
        items = const [],
        error = null,
        working = false;

  final EquipmentStatus status;
  final List<Equipment> items;
  final String? error;
  final bool working;

  EquipmentState copyWith({
    EquipmentStatus? status,
    List<Equipment>? items,
    String? error,
    bool? working,
  }) {
    return EquipmentState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error,
      working: working ?? this.working,
    );
  }

  @override
  List<Object?> get props => [status, items, error, working];
}
