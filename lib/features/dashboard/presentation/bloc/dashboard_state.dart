part of 'dashboard_bloc.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({required this.status, this.stats, this.error});
  const DashboardState.initial() : status = DashboardStatus.initial, stats = null, error = null;

  final DashboardStatus status;
  final DashboardStats? stats;
  final String? error;

  DashboardState copyWith({DashboardStatus? status, DashboardStats? stats, String? error}) {
    return DashboardState(status: status ?? this.status, stats: stats ?? this.stats, error: error);
  }

  @override
  List<Object?> get props => [status, stats, error];
}
