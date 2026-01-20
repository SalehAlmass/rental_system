import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/reports/data/repositories/payments_report_repository.dart';


sealed class PaymentsReportState {}

class PaymentsReportInitial extends PaymentsReportState {}

class PaymentsReportLoading extends PaymentsReportState {}

class PaymentsReportLoaded extends PaymentsReportState {
  final Map<String, dynamic> totals; // in/out/net
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> filter; // from/to/type/include_void

  PaymentsReportLoaded({
    required this.totals,
    required this.rows,
    required this.filter,
  });
}

class PaymentsReportError extends PaymentsReportState {
  final String message;
  PaymentsReportError(this.message);
}

class PaymentsReportCubit extends Cubit<PaymentsReportState> {
  final PaymentsReportRepository repo;

  String? _from;
  String? _to;
  String _type = 'all';

  PaymentsReportCubit(this.repo) : super(PaymentsReportInitial());

  void setFilter({String? from, String? to, String? type}) {
    _from = from;
    _to = to;
    if (type != null) _type = type;
  }

  void clearFilter() {
    _from = null;
    _to = null;
    _type = 'all';
  }

  String? get from => _from;
  String? get to => _to;
  String get type => _type;

  Future<void> load() async {
    try {
      emit(PaymentsReportLoading());
      final res = await repo.fetchPaymentsReport(
        from: _from,
        to: _to,
        type: _type,
      );

      final totals = (res['totals'] as Map?)?.cast<String, dynamic>() ?? {};
      final filter = (res['filter'] as Map?)?.cast<String, dynamic>() ?? {
        'from': _from,
        'to': _to,
        'type': _type,
      };

      final dataList = (res['data'] as List?) ?? const [];
      final rows = dataList
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      emit(PaymentsReportLoaded(
        totals: totals,
        rows: rows,
        filter: filter,
      ));
    } catch (e) {
      emit(PaymentsReportError(e.toString()));
    }
  }
}
