part of 'dashboard_bloc.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({required this.status, this.stats, this.recentRents = const [], this.error});
  const DashboardState.initial()
      : status = DashboardStatus.initial,
        stats = null,
        recentRents = const [],
        error = null;

  final DashboardStatus status;
  final DashboardStats? stats;
  final List<Rent> recentRents;
  final String? error;

  DashboardState copyWith({DashboardStatus? status, DashboardStats? stats, List<Rent>? recentRents, String? error}) {
    return DashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      recentRents: recentRents ?? this.recentRents,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, stats, recentRents, error];
}
