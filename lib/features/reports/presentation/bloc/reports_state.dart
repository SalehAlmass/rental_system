import 'package:equatable/equatable.dart';
import '../../domain/entities/report_dashboard.dart';

enum ReportsStatus { initial, loading, success, failure }

class ReportsState extends Equatable {
  const ReportsState({
    required this.status,
    this.data,
    this.error,
  });

  const ReportsState.initial()
      : status = ReportsStatus.initial,
        data = null,
        error = null;

  final ReportsStatus status;
  final ReportDashboard? data;
  final String? error;

  ReportsState copyWith({
    ReportsStatus? status,
    ReportDashboard? data,
    String? error,
  }) {
    return ReportsState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, data, error];
}
