import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:dio/dio.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';
import 'package:rental_app/features/clients/presentation/ui/client_details_page.dart';
import 'package:rental_app/core/utils/debouncer.dart';

import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/rents/presentation/bloc/rents_bloc.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/settings/data/contract_closing_settings_repository.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/core/utils/datetime_utils.dart';

String nowSql() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return "${n.year}-${two(n.month)}-${two(n.day)} "
      "${two(n.hour)}:${two(n.minute)}:${two(n.second)}";
}

String? validateRate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final numValue = double.tryParse(value.trim());
  if (numValue == null || numValue < 0) {
    return 'الرجاء إدخال قيمة عددية صحيحة';
  }
  return null;
}

/// ===============================
/// Financial helpers
/// ===============================
DateTime? _tryParseRentDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTimeUtils.parse(value);
}

double safeRentPaid(Rent rent) {
  final paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
  return paid < 0 ? 0 : paid;
}

double safeRentTotal(Rent rent) {
  final status = (rent.status ?? '').toLowerCase();
  if (status == 'cancelled') return 0;

  // ✅ Priority 1: Use total_amount from API when available (valid for ALL statuses).
  // The backend computes this correctly — including open rents (rents.php:282).
  // Dynamic calculation below is a fallback only when API value is absent.
  if ((rent.totalAmount ?? 0) > 0) {
    return rent.totalAmount!;
  }

  // ✅ Priority 2: Dynamic calculation from items (fallback when total_amount = null/0)
  final now = DateTime.now();

  if (rent.items.isNotEmpty) {
    double total = 0;
    for (final item in rent.items) {
      // Skip replaced items — successor item covers its period, avoid double counting
      if ((item.status ?? '').toLowerCase() == 'replaced') continue;

      final rate = item.rate ?? 0;
      final start = item.parsedStartDatetime ?? rent.parsedStartDatetime;
      if (start == null) continue;
      
      final end = item.parsedEndDatetime ?? now;
      final diff = end.difference(start);
      final hours = diff.inMinutes / 60.0;
      int billableDays = (hours / 24.0).ceil();
      if (billableDays < 1) billableDays = 1;
      
      total += rate * billableDays;
    }
    return total.round().toDouble();
  } else {
    final rate = rent.rate ?? 0;
    final start = rent.parsedStartDatetime;
    if (start == null) return 0;
    
    final end = rent.parsedEndDatetime ?? now;
    final diff = end.difference(start);
    final hours = diff.inMinutes / 60.0;
    int billableDays = (hours / 24.0).ceil();
    if (billableDays < 1) billableDays = 1;
    
    return (rate * billableDays).round().toDouble();
  }
}

double safeRentRemaining(Rent rent) {
  final status = (rent.status ?? '').toLowerCase();
  if (status == 'open') {
    final total = safeRentTotal(rent);
    final paid = safeRentPaid(rent);
    final remaining = total - paid;
    return remaining > 0 ? remaining : 0;
  }

  final direct = rent.remainingAmount;
  if (direct != null) {
    return direct < 0 ? 0 : direct;
  }

  final total = safeRentTotal(rent);
  final paid = safeRentPaid(rent);
  final remaining = total - (rent.discountAmount ?? 0) - paid;
  return remaining > 0 ? remaining : 0;
}

class RentsPage extends StatelessWidget {
  final String initialFilter;

  const RentsPage({
    super.key,
    this.initialFilter = 'open',
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => RentsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => ClientsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => EquipmentRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => ContractClosingSettingsRepository(context.read<ApiClient>()),
        ),
      ],
      child: BlocProvider(
        create: (context) =>
            RentsBloc(context.read<RentsRepository>())
              ..add(RentsRequested(status: initialFilter)),
        child: _RentsView(
          showBackButton: Navigator.canPop(context),
          initialFilter: initialFilter,
        ),
      ),
    );
  }
}

class _RentsView extends StatefulWidget {
  const _RentsView({
    this.showBackButton = true,
    this.initialFilter = 'open',
  });
  final bool showBackButton;
  final String initialFilter;

  @override
  State<_RentsView> createState() => _RentsViewState();
}

class _RentsViewState extends State<_RentsView> {
  String _statusFilter = 'all';
  String _query = '';
  String _collectionSort = 'oldest';
  Timer? _debounce;

  /// Lazy loading: how many items to display from the filtered list
  int _displayLimit = 50;
  bool _archiving = false;

  bool _loadingAgenda = false;
  List<_CollectionAgendaItem> _agendaItems = const [];

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter;
    _fetchCollectionAgenda();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCollectionAgenda() async {
    setState(() => _loadingAgenda = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.dio.get(
        'rents/collection-agenda',
        queryParameters: {
          'sort': _collectionSort,
          't': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(validateStatus: (status) => status != null && status < 600),
      );

      if (!mounted) return;

      dynamic raw = res.data;
      if (raw is Map) {
        raw = raw['data'] ?? raw['items'] ?? raw['agenda'] ?? [];
      }
      if (raw is! List) raw = [];

      final items = raw
          .whereType<Map>()
          .map((e) => _CollectionAgendaItem.fromJson(e.cast<String, dynamic>()))
          .toList();

      if (!mounted) return;
      setState(() {
        _agendaItems = items;
        _loadingAgenda = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _agendaItems = const [];
        _loadingAgenda = false;
      });
    }
  }

  String? get _statusParam {
    switch (_statusFilter) {
      case 'all':
        return null;
      case 'open':
      case 'closed':
      case 'cancelled':
      case 'archived':
      case 'review':
      case 'overdue':
      case 'deferred':
        return _statusFilter;
      default:
        return null;
    }
  }

  Future<void> _reloadEverything() async {
    if (!mounted) return;
    final rstate = context.read<RentsBloc>().state;
    context.read<RentsBloc>().add(RentsRequested(
      status: _statusParam,
      page: rstate.currentPage,
      perPage: rstate.perPage,
      searchQuery: _query,
    ));
    await _fetchCollectionAgenda();
  }

  void _setFilter(String filter) {
    if (_statusFilter == filter) return;
    setState(() {
      _statusFilter = filter;
    });
    // Reset to page 1 when changing filters
    if (!mounted) return;
    final rstate = context.read<RentsBloc>().state;
    context.read<RentsBloc>().add(RentsRequested(
      status: _statusParam,
      page: 1,
      perPage: rstate.perPage,
      searchQuery: _query,
    ));
    _fetchCollectionAgenda();
  }

  Future<void> _openDetails(BuildContext context, int rentId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: rentId)),
    );

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _reloadEverything();
  }


  Future<void> _openQuickClose(BuildContext context, Rent rent) async {
    final repo = context.read<RentsRepository>();
    final settingsRepo = context.read<ContractClosingSettingsRepository>();
    final paymentsRepo = PaymentsRepository(context.read<ApiClient>());
    final total = safeRentTotal(rent);
    final paid = safeRentPaid(rent);
    final remaining = safeRentRemaining(rent);

    final settings = await settingsRepo.fetch();
    if (!mounted) return;

    final result = await showDialog<QuickCloseResult>(
      context: context,
      builder: (_) => QuickCloseDialog(
        rent: rent,
        settings: settings,
        totalAmount: total,
        currentPaid: paid,
        remainingAmount: remaining,
      ),
    );
    if (result == null) return;

    await repo.closeRent(
      rentId: rent.id,
      endDatetime: DateTime.now().toIso8601String(),
      applySpecialPricing: result.applySpecialPricing,
      paidAmount: result.paidAmount,
      discountAmount: result.discountAmount,
      discountNote: result.discountNote,
      paymentMethod: result.paymentMethod,
      createReceipt: false,
      paymentNotes: result.paymentNotes,
      idempotencyKey: 'quick_close_${rent.id}_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
    if (result.paidAmount > 0) {
      await paymentsRepo.create(
        type: 'in',
        amount: result.paidAmount,
        clientId: rent.clientId,
        rentId: rent.id,
        method: result.paymentMethod,
        notes: result.paymentNotes ?? 'سند قبض بعد الإغلاق السريع',
        idempotencyKey: 'quick_close_receipt_${rent.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsPage()));
      }
    }

    await _reloadEverything();
  }

  List<Rent> _applyUiFilters(List<Rent> items) {
    return items;
  }

  bool _isOverdue(Rent rent) {
    final status = (rent.status ?? '').toLowerCase();
    if (status != 'open') return false;
    final start = rent.parsedStartDatetime;
    if (start == null) return false;
    return DateTime.now().difference(start).inHours >= 24;
  }

  double _remainingAmount(Rent rent) => safeRentRemaining(rent);

  bool _isClosedWithDeferredPayment(Rent rent) {
    final status = (rent.status ?? '').toLowerCase();
    return status == 'closed' && safeRentRemaining(rent) > 0.009;
  }

  bool _needsReview(Rent rent) {
    final status = (rent.status ?? '').toLowerCase();
    if (status == 'closed') {
      return (rent.closingPaymentStatus ?? '').toLowerCase() != 'created' ||
          _isClosedWithDeferredPayment(rent);
    }
    return _isOverdue(rent);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'العقود',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _reloadEverything,
            icon: const Icon(Icons.refresh),
          ),
        ],
        onIconPressed: widget.showBackButton
            ? () => Navigator.pop(context)
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rents_fab',
        icon: const Icon(Icons.add),
        label: const Text('فتح عقد'),
        onPressed: () => _openDialog(context),
      ),
      body: PageEntrance(
        child: BlocConsumer<RentsBloc, RentsState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (context, state) {
            if (state.status == RentsStatus.loading && state.items.isEmpty && _query.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final filtered = _applyUiFilters(state.items);
            final collectionToday = _agendaItems;
            final stats = _RentStats.from(
              state.items,
              _isOverdue,
              _needsReview,
              _isClosedWithDeferredPayment,
              _remainingAmount,
            );

            return RefreshIndicator(
              onRefresh: () async {
                await _reloadEverything();
                await Future<void>.delayed(const Duration(milliseconds: 200));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'إدارة العقود اليومية',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _reloadEverything,
                              tooltip: 'تحديث البيانات',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اعرض العقود المفتوحة والمغلقة بسرعة، وراجع العقود المتأخرة أو التي أغلقت بدون سند قبض.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              if (!mounted) return;
                              final rstate = context.read<RentsBloc>().state;
                              context.read<RentsBloc>().add(RentsRequested(
                                status: _statusParam,
                                page: 1, // Reset to page 1 when searching
                                perPage: rstate.perPage,
                                searchQuery: _query,
                              ));
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'ابحث برقم العقد أو العميل أو المعدة أو رقم السند',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.status == RentsStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: LinearProgressIndicator(),
                    ),
                  if (stats.overdue > 0 || stats.deferredCount > 0)
                    () {
                      final isOverdue = stats.overdue > 0;
                      final tone = isOverdue ? Colors.red : Colors.orange;
                      final alertTitle = isOverdue
                          ? 'لديك عقود متأخرة تحتاج متابعة الآن'
                          : 'هناك عقود مغلقة لكن ما زال عليها رصيد مؤجل';
                      final alertIcon = isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.account_balance_wallet_outlined;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: tone.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(alertIcon, color: tone),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alertTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'المتأخرة: ${stats.overdue} • المؤجلة: ${stats.deferredCount} • المتبقي: ${stats.deferredAmount.round()} ${AppConfig.currencySymbol}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _setFilter(isOverdue ? 'overdue' : 'deferred'),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('عرض الآن'),
                            ),
                          ],
                        ),
                      );
                    }(),
                  SizedBox(
                    height: 124,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'كل العقود',
                          value: stats.total.toString(),
                          icon: Icons.assignment_outlined,
                          tone: colorScheme.primary,
                          onTap: () => _setFilter('all'),
                        ),
                        _StatCard(
                          title: 'مفتوحة',
                          value: stats.open.toString(),
                          icon: Icons.lock_open_rounded,
                          tone: Colors.blue,
                          onTap: () => _setFilter('open'),
                        ),
                        _StatCard(
                          title: 'متأخرة',
                          value: stats.overdue.toString(),
                          icon: Icons.warning_amber_rounded,
                          tone: Colors.red,
                          onTap: () => _setFilter('overdue'),
                        ),
                        _StatCard(
                          title: 'تسديد مؤجل',
                          value: stats.deferredCount.toString(),
                          icon: Icons.account_balance_wallet_outlined,
                          tone: Colors.orange,
                          onTap: () => _setFilter('deferred'),
                          subtitle:
                              '${stats.deferredAmount.toStringAsFixed(0)} ${AppConfig.currencySymbol}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'متابعة التحصيل اليومية',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'تعرض العقود المتأخرة أو المؤجلة، وتوضح فورًا هل تم التواصل مع العميل اليوم ومن قام بذلك حتى لا يتكرر التواصل بين الموظفين.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'oldest',
                                  icon: Icon(Icons.history_toggle_off),
                                  label: Text('الأقدم'),
                                ),
                                ButtonSegment(
                                  value: 'largest',
                                  icon: Icon(Icons.trending_up),
                                  label: Text('الأكبر'),
                                ),
                                ButtonSegment(
                                  value: 'scheduled',
                                  icon: Icon(Icons.event_available_outlined),
                                  label: Text('المجدول'),
                                ),
                              ],
                              selected: {_collectionSort},
                              onSelectionChanged: (value) {
                                if (value.isEmpty) return;
                                setState(() => _collectionSort = value.first);
                                _fetchCollectionAgenda();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loadingAgenda)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (collectionToday.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'لا توجد عقود بحاجة لتحصيل حاليًا',
                            ),
                          )
                        else
                          Column(
                            children: collectionToday
                                .take(5)
                                .map(
                                  (item) => Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: item.hasContactToday
                                            ? Colors.blue.withOpacity(0.12)
                                            : Colors.orange.withOpacity(0.12),
                                        child: Icon(
                                          item.hasContactToday
                                              ? Icons.phone_in_talk_outlined
                                              : Icons
                                                    .account_balance_wallet_outlined,
                                          color: item.hasContactToday
                                              ? Colors.blue
                                              : Colors.orange,
                                        ),
                                      ),
                                      title: Text(
                                        'عقد #${item.id} • ${item.clientName}',
                                      ),
                                      subtitle: Text(
                                        _collectionAgendaSubtitle(item),
                                      ),
                                      isThreeLine: true,
                                      trailing: const Icon(Icons.chevron_left),
                                      onTap: () =>
                                          _openDetails(context, item.id),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        if (collectionToday.length > 5)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _setFilter('deferred'),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(
                                'عرض كل عقود التحصيل (${collectionToday.length})',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'الكل',
                        selected: _statusFilter == 'all',
                        onTap: () => _setFilter('all'),
                      ),
                      _FilterChip(
                        label: 'مفتوحة',
                        selected: _statusFilter == 'open',
                        onTap: () => _setFilter('open'),
                      ),
                      _FilterChip(
                        label: 'مغلقة',
                        selected: _statusFilter == 'closed',
                        onTap: () => _setFilter('closed'),
                      ),
                      _FilterChip(
                        label: 'ملغاة',
                        selected: _statusFilter == 'cancelled',
                        onTap: () => _setFilter('cancelled'),
                      ),
                      _FilterChip(
                        label: 'متأخرة',
                        selected: _statusFilter == 'overdue',
                        onTap: () => _setFilter('overdue'),
                      ),
                      _FilterChip(
                        label: 'بحاجة مراجعة',
                        selected: _statusFilter == 'review',
                        onTap: () => _setFilter('review'),
                      ),
                      _FilterChip(
                        label: 'تسديد مؤجل',
                        selected: _statusFilter == 'deferred',
                        onTap: () => _setFilter('deferred'),
                      ),
                      _FilterChip(
                        label: 'مؤرشفة',
                        selected: _statusFilter == 'archived',
                        onTap: () => _setFilter('archived'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'العقود المعروضة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      // Archive button (admin only)
                      Builder(
                        builder: (ctx) {
                          final pstate = ctx.read<ProfileCubit>().state;
                          final isAdmin = pstate is ProfileLoaded &&
                              pstate.user['role']?.toString() == 'admin';
                          if (!isAdmin) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _archiving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : ActionChip(
                                    avatar: Icon(
                                      Icons.archive_outlined,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    label: const Text('أرشفة المكتملة'),
                                    onPressed: () => _archiveClosedRents(context),
                                  ),
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${state.totalCount} نتيجة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSortingBar(context, state),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 42,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.items.isEmpty
                                ? 'لا توجد عقود حتى الآن'
                                : 'لا توجد عقود مطابقة للفلترة الحالية',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ...filtered.map(
                      (rent) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RentCard(
                          rent: rent,
                          isOverdue: _isOverdue(rent),
                          needsReview: _needsReview(rent),
                          isClosedWithDeferredPayment:
                              _isClosedWithDeferredPayment(rent),
                          remainingAmount: _remainingAmount(rent),
                          onOpenDetails: () => _openDetails(context, rent.id),
                          onQuickClose: () => _openQuickClose(context, rent),
                          onCancelled: (rentId) {
                            context.read<RentsBloc>().add(
                              RentCancelled(rentId: rentId),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: state.currentPage > 1
                                ? () {
                                    context.read<RentsBloc>().add(RentsRequested(
                                      status: _statusParam,
                                      page: state.currentPage - 1,
                                      perPage: state.perPage,
                                      searchQuery: _query,
                                    ));
                                  }
                                : null,
                            tooltip: 'الصفحة السابقة',
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'الصفحة ${state.currentPage} من ${((state.totalCount == 0 ? 1 : state.totalCount) / state.perPage).ceil()}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: state.currentPage < ((state.totalCount == 0 ? 1 : state.totalCount) / state.perPage).ceil()
                                ? () {
                                    context.read<RentsBloc>().add(RentsRequested(
                                      status: _statusParam,
                                      page: state.currentPage + 1,
                                      perPage: state.perPage,
                                      searchQuery: _query,
                                    ));
                                  }
                                : null,
                            tooltip: 'الصفحة التالية',
                          ),
                          const SizedBox(width: 24),
                          DropdownButton<int>(
                            value: state.perPage,
                            items: [10, 20, 50, 100].map((val) {
                              return DropdownMenuItem<int>(
                                value: val,
                                child: Text('$val عقد / صفحة'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                context.read<RentsBloc>().add(RentsRequested(
                                  status: _statusParam,
                                  page: 1,
                                  perPage: val,
                                  searchQuery: _query,
                                ));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _archiveClosedRents(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.archive_outlined, size: 36),
        title: const Text('أرشفة العقود المكتملة'),
        content: const Text(
          'سيتم إخفاء جميع العقود المغلقة والمدفوعة بالكامل من القائمة.\n'
          'البيانات تبقى محفوظة في التقارير ويمكن استعادتها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('أرشفة الآن'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _archiving = true);

    try {
      final repo = context.read<RentsRepository>();
      final count = await repo.archiveClosed();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم أرشفة $count عقد بنجاح')),
      );

      await _reloadEverything();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الأرشفة: $e')),
      );
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  String _collectionAgendaSubtitle(_CollectionAgendaItem item) {
    final lines = <String>[
      'المتبقي: ${item.remainingAmount.toStringAsFixed(0)} ${AppConfig.currencySymbol}',
    ];

    if (item.hasScheduledFollowupToday) {
      lines.add(
        'متابعة مجدولة اليوم ${item.nextFollowupAtLabel}${item.latestCreatedByName == null ? '' : ' • بواسطة ${item.latestCreatedByName}'}',
      );
    } else if (item.hasUpcomingScheduledFollowup) {
      lines.add('المتابعة القادمة: ${item.nextFollowupAtLabel}');
    }

    if (item.hasContactToday) {
      lines.add(
        'تم التواصل اليوم بواسطة ${item.todayCreatedByName ?? 'أحد الموظفين'} ${item.todayCreatedAtLabel}',
      );
    } else if (item.latestCreatedAt != null) {
      lines.add(
        'آخر تواصل: ${item.latestCreatedByName ?? 'أحد الموظفين'} • ${item.latestCreatedAtLabel}',
      );
    } else {
      lines.add('لا توجد متابعة تحصيل مسجلة حتى الآن');
    }

    return lines.join('\n');
  }

  Future<void> _openDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<RentsBloc>(),
        child: _OpenRentDialog(
          clientsRepo: context.read<ClientsRepository>(),
          equipmentRepo: context.read<EquipmentRepository>(),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _reloadEverything();
    }
  }

  Widget _buildSortingBar(BuildContext context, RentsState state) {
    final bloc = context.read<RentsBloc>();
    final currentSortBy = state.sortBy ?? 'id';
    final currentSortOrder = state.sortOrder ?? 'desc';

    final sortOptions = {
      'id': 'رقم العقد',
      'client_name': 'اسم العميل',
      'start_datetime': 'تاريخ البداية',
      'end_datetime': 'تاريخ النهاية',
      'status': 'الحالة',
    };

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentSortBy,
            underline: const SizedBox(),
            items: sortOptions.entries.map((e) {
              return DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                bloc.add(RentsRequested(
                  status: state.filterStatus,
                  page: 1,
                  perPage: state.perPage,
                  searchQuery: state.searchQuery,
                  sortBy: val,
                  sortOrder: currentSortOrder,
                ));
              }
            },
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              currentSortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
            ),
            onPressed: () {
              final nextOrder = currentSortOrder == 'asc' ? 'desc' : 'asc';
              bloc.add(RentsRequested(
                status: state.filterStatus,
                page: 1,
                perPage: state.perPage,
                searchQuery: state.searchQuery,
                sortBy: currentSortBy,
                sortOrder: nextOrder,
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _RentCard extends StatelessWidget {
  const _RentCard({
    required this.rent,
    required this.isOverdue,
    required this.needsReview,
    required this.isClosedWithDeferredPayment,
    required this.remainingAmount,
    required this.onOpenDetails,
    required this.onQuickClose,
    required this.onCancelled,
  });

  final Rent rent;
  final bool isOverdue;
  final bool needsReview;
  final bool isClosedWithDeferredPayment;
  final double remainingAmount;
  final VoidCallback onOpenDetails;
  final VoidCallback onQuickClose;
  final void Function(int rentId) onCancelled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = (rent.status ?? '').toLowerCase();
    final isClosed = status == 'closed';
    final isCancelled = status == 'cancelled';
    final paymentStatus = (rent.closingPaymentStatus ?? '').toLowerCase();

    final total = safeRentTotal(rent);
    final paid = safeRentPaid(rent);
    final remaining = safeRentRemaining(rent);

    final start = rent.parsedStartDatetime;
    String daysText = '';
    if (start != null) {
      final end = rent.parsedEndDatetime ?? DateTime.now();
      final diff = end.difference(start);
      final hours = diff.inMinutes / 60.0;
      int days = (hours / 24.0).ceil();
      if (days < 1) days = 1;
      
      if (days == 1) {
        daysText = 'يوم واحد';
      } else if (days == 2) {
        daysText = 'يومين';
      } else if (days >= 3 && days <= 10) {
        daysText = '$days أيام';
      } else {
        daysText = '$days يوم';
      }
    }

    final accent = isCancelled
        ? Colors.grey
        : isClosed
        ? (isClosedWithDeferredPayment ? Colors.orange : Colors.green)
        : (isOverdue ? Colors.red : Colors.blue);

    final statusLabel = isCancelled
        ? 'ملغي'
        : isClosed
        ? (isClosedWithDeferredPayment ? 'مغلق والسداد مؤجل' : 'مغلق')
        : isOverdue
        ? 'مفتوح ومتأخر'
        : 'مفتوح';

    final receiptLabel = paymentStatus == 'created'
        ? 'تم إنشاء السند'
        : isClosed
        ? 'أغلق بدون سند'
        : 'لم يُغلق بعد';

    final discount = rent.discountAmount ?? 0;
    final discountText = discount > 0 ? ' • خصم ${discount.round()} ${AppConfig.currencySymbol}' : '';
    final financialHint = remaining > 0.009
        ? 'متبقٍ على العميل ${remaining.round()} ${AppConfig.currencySymbol}$discountText'
        : '${rent.pricingRuleLabel ?? 'الاحتساب القياسي'}$discountText';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onOpenDetails,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCancelled
                            ? Icons.block_rounded
                            : isClosed
                            ? Icons.task_alt_rounded
                            : Icons.description_outlined,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عقد #${rent.id}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rent.clientName ?? 'عميل غير محدد',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _Pill(label: statusLabel, color: accent),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.precision_manufacturing_outlined,
                      text: rent.equipmentName ?? 'معدة غير محددة',
                    ),
                    _InfoPill(
                      icon: Icons.login_rounded,
                      text: rent.startDatetime,
                    ),
                    _InfoPill(
                      icon: Icons.logout_rounded,
                      text: rent.endDatetime ?? 'العقد جاري',
                    ),
                    if (daysText.isNotEmpty)
                      _InfoPill(
                        icon: Icons.timer_outlined,
                        text: daysText,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'الإجمالي',
                        value: total <= 0 && status == 'open'
                            ? 'جاري...'
                            : '${total.round()} ${AppConfig.currencySymbol}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniMetric(
                        label: remaining > 0.009 ? 'المتبقي' : 'المدفوع',
                        value: remaining > 0.009
                            ? '${remaining.round()} ${AppConfig.currencySymbol}'
                            : '${paid.round()} ${AppConfig.currencySymbol}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: needsReview
                        ? Colors.orange.withOpacity(0.08)
                        : colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: needsReview
                          ? Colors.orange.withOpacity(0.35)
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        needsReview
                            ? Icons.warning_amber_rounded
                            : Icons.receipt_long_outlined,
                        color: needsReview
                            ? Colors.orange
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receiptLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              financialHint,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rent.closingPaymentId != null)
                        Text(
                          '#${rent.closingPaymentId}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenDetails,
                        icon: Icon(
                          isClosed
                              ? Icons.visibility_outlined
                              : Icons.edit_note_outlined,
                        ),
                        label: Text(isClosed ? 'عرض التفاصيل' : 'إدارة العقد'),
                      ),
                    ),
                    if (!isCancelled) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isClosed ? onOpenDetails : onQuickClose,
                          icon: Icon(
                            isClosed
                                ? Icons.receipt_long
                                : Icons.lock_clock_outlined,
                          ),
                          label: Text(
                            isClosed ? 'مراجعة الإغلاق' : 'إغلاق سريع',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!isClosed && !isCancelled) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('تأكيد إلغاء العقد'),
                            content: Text(
                              'هل تريد إلغاء العقد رقم #${rent.id} ؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('تراجع'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('إلغاء العقد'),
                              ),
                            ],
                          ),
                        );

                        if (ok == true && context.mounted) {
                          onCancelled(rent.id);
                        }
                      },
                      icon: const Icon(Icons.block),
                      label: const Text('إلغاء العقد'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
    this.subtitle,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsetsDirectional.only(end: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tone.withOpacity(0.18), tone.withOpacity(0.07)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tone.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: tone.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tone, size: 18),
                ),
                const Spacer(),
                if (subtitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tone,
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: tone,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle == null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tone.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RentStats {
  const _RentStats({
    required this.total,
    required this.open,
    required this.closed,
    required this.review,
    required this.overdue,
    required this.deferredCount,
    required this.deferredAmount,
  });

  final int total;
  final int open;
  final int closed;
  final int review;
  final int overdue;
  final int deferredCount;
  final double deferredAmount;

  factory _RentStats.from(
    List<Rent> items,
    bool Function(Rent rent) isOverdue,
    bool Function(Rent rent) needsReview,
    bool Function(Rent rent) isClosedWithDeferredPayment,
    double Function(Rent rent) remainingAmount,
  ) {
    int open = 0;
    int closed = 0;
    int review = 0;
    int overdue = 0;
    int deferredCount = 0;
    double deferredAmount = 0;

    for (final rent in items) {
      final status = (rent.status ?? '').toLowerCase();
      if (status == 'open') open++;
      if (status == 'closed') closed++;
      if (needsReview(rent) || isOverdue(rent)) review++;
      if (isOverdue(rent)) overdue++;
      if (isClosedWithDeferredPayment(rent)) {
        deferredCount++;
        deferredAmount += remainingAmount(rent);
      }
    }

    return _RentStats(
      total: items.length,
      open: open,
      closed: closed,
      review: review,
      overdue: overdue,
      deferredCount: deferredCount,
      deferredAmount: deferredAmount,
    );
  }
}

class _OpenRentDialog extends StatefulWidget {
  const _OpenRentDialog({
    required this.clientsRepo,
    required this.equipmentRepo,
  });

  final ClientsRepository clientsRepo;
  final EquipmentRepository equipmentRepo;

  @override
  State<_OpenRentDialog> createState() => _OpenRentDialogState();
}

class _OpenRentDialogState extends State<_OpenRentDialog> {
  List<Client> _clients = [];
  List<Equipment> _allEquipment = [];

  int? _clientId;

  /// Equipment IDs that the user has checked
  final Set<int> _selectedIds = {};
  final Map<int, Equipment> _selectedEquipmentMap = {};

  /// Per-equipment custom rate (optional)
  final Map<int, TextEditingController> _rateControllers = {};

  /// Per-equipment notes (optional)
  final Map<int, TextEditingController> _notesControllers = {};

  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  Future<List<Client>> _fetchClients(String filter) async {
    final q = filter.trim();
    if (q.isEmpty) return _clients;

    try {
      // DropdownSearch has its own native searchDelay, avoiding the need for
      // custom debouncers with uncompleted Futures that hang the UI in Release Web Mode.
      return await widget.clientsRepo.list(query: q);
    } catch (_) {
      return [];
    }
  }

  bool _loading = true;
  bool _submitted = false;
  bool _localSubmitting = false;

  /// Filter: 'all', 'available', 'rented', 'maintenance', 'inactive'
  String _statusFilter = 'available';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.clientsRepo.list();
    final e = await widget.equipmentRepo.list();

    if (!mounted) return;

    setState(() {
      _clients = c;
      _allEquipment = e;
      _clientId = _clients.isNotEmpty ? _clients.first.id : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────

  bool _isSelectable(Equipment eq) {
    final s = (eq.status ?? 'available').toLowerCase();
    return s == 'available' && eq.isActive;
  }

  String _unavailableReason(Equipment eq) {
    final s = (eq.status ?? 'available').toLowerCase();
    if (!eq.isActive) return 'غير نشطة';
    if (s == 'rented') return 'مؤجرة حالياً';
    if (s == 'maintenance') return 'تحت الصيانة';
    return 'غير متاحة';
  }

  String _statusLabel(String? status) {
    switch ((status ?? 'available').toLowerCase()) {
      case 'rented':
        return 'مؤجرة';
      case 'maintenance':
        return 'صيانة';
      case 'available':
        return 'متاحة';
      default:
        return status ?? 'غير معروف';
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? 'available').toLowerCase()) {
      case 'rented':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      case 'available':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  TextEditingController _rateCtrl(int id, double defaultRate) {
    return _rateControllers.putIfAbsent(id, () {
      return TextEditingController(
        text: defaultRate > 0 ? defaultRate.toStringAsFixed(0) : '',
      );
    });
  }

  TextEditingController _notesCtrl(int id) {
    return _notesControllers.putIfAbsent(id, () => TextEditingController());
  }

  // ── filtering & sorting ───────────────────────────────────────────────

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.equipmentRepo.list(
          query: query.trim().isNotEmpty ? query.trim() : null,
          status: _statusFilter != 'all' ? _statusFilter : null,
        );
        if (mounted) {
          setState(() {
            _allEquipment = results;
          });
        }
      } catch (_) {}
    });
  }

  void _onStatusFilterChanged(String value) async {
    setState(() {
      _statusFilter = value;
      _loading = true;
    });
    try {
      final query = _searchCtrl.text.trim();
      final results = await widget.equipmentRepo.list(
        query: query.isNotEmpty ? query : null,
        status: value != 'all' ? value : null,
      );
      if (mounted) {
        setState(() {
          _allEquipment = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Equipment> get _filteredSortedEquipment {
    final list = <Equipment>[];

    // 1. Add all selected equipment items first (so they are always visible)
    list.addAll(_selectedEquipmentMap.values);

    // 2. Add currently fetched results from the server if they are not already in the list
    for (final eq in _allEquipment) {
      if (!list.any((item) => item.id == eq.id)) {
        list.add(eq);
      }
    }

    // Sort: selected first → available → rest
    list.sort((a, b) {
      final aSelected = _selectedIds.contains(a.id) ? 0 : 1;
      final bSelected = _selectedIds.contains(b.id) ? 0 : 1;
      if (aSelected != bSelected) return aSelected.compareTo(bSelected);

      final aAvail = _isSelectable(a) ? 0 : 1;
      final bAvail = _isSelectable(b) ? 0 : 1;
      if (aAvail != bAvail) return aAvail.compareTo(bAvail);

      return a.name.compareTo(b.name);
    });

    return list;
  }

  void _selectAllAvailable() {
    setState(() {
      for (final eq in _filteredSortedEquipment) {
        if (_isSelectable(eq)) {
          _selectedIds.add(eq.id);
          _selectedEquipmentMap[eq.id] = eq;
        }
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
      _selectedEquipmentMap.clear();
    });
  }

  void _toggleEquipment(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
        final eq = _allEquipment.firstWhere(
          (item) => item.id == id,
          orElse: () => _selectedEquipmentMap[id]!,
        );
        _selectedEquipmentMap[id] = eq;
      } else {
        _selectedIds.remove(id);
        _selectedEquipmentMap.remove(id);
        _rateControllers.remove(id)?.dispose();
        _notesControllers.remove(id)?.dispose();
      }
    });
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 700 ? 620.0 : screenWidth * 0.92;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.description_outlined, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(child: Text('فتح عقد جديد')),
          if (!_loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedIds.isEmpty
                    ? Colors.grey.shade200
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _selectedIds.isEmpty ? Colors.grey : Colors.blue.shade300,
                ),
              ),
              child: Text(
                'تم اختيار: ${_selectedIds.length} معدة',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      _selectedIds.isEmpty ? Colors.grey.shade600 : Colors.blue,
                ),
              ),
            ),
        ],
      ),
      content: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: dialogWidth,
              height: 520,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Client picker ──
                    DropdownSearch<Client>(
                      items: (filter, _) => _fetchClients(filter),
                      compareFn: (i, s) => i.id == s.id,
                      itemAsString: (Client c) => '${c.id} - ${c.name}',
                      selectedItem: _clients.isNotEmpty
                          ? _clients.firstWhere((c) => c.id == _clientId,
                              orElse: () => _clients.first)
                          : null,
                      onChanged: (Client? data) {
                        if (data != null) setState(() => _clientId = data.id);
                      },
                      decoratorProps: const DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'العميل',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchDelay: const Duration(milliseconds: 400),
                        searchFieldProps: const TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم، رقم الجوال، أو الهوية...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        itemBuilder:
                            (context, item, isDisabled, isSelected) =>
                                ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                              '${item.phone ?? ""} | ${item.nationalId ?? ""}'),
                          selected: isSelected,
                          trailing: Text('#${item.id}'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // ── Equipment section header ──
                    const Text(
                      'اختر المعدات للعقد',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),

                    // ── Search bar ──
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم، الرقم التسلسلي، أو رقم المعدة...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Filter chips + Select all / Deselect all ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('الكل', 'all'),
                          const SizedBox(width: 4),
                          _filterChip('متاحة', 'available'),
                          const SizedBox(width: 4),
                          _filterChip('مؤجرة', 'rented'),
                          const SizedBox(width: 4),
                          _filterChip('صيانة', 'maintenance'),
                          const SizedBox(width: 4),
                          _filterChip('غير نشطة', 'inactive'),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: _selectAllAvailable,
                            icon: const Icon(Icons.select_all, size: 18),
                            label: const Text('تحديد الكل',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed:
                                _selectedIds.isEmpty ? null : _deselectAll,
                            icon: const Icon(Icons.deselect, size: 18),
                            label: const Text('إلغاء الكل',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Equipment list ──
                    Expanded(child: _buildEquipmentList()),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        BlocConsumer<RentsBloc, RentsState>(
          listener: (context, state) {
            if (state.error != null) {
              _submitted = false;
              setState(() => _localSubmitting = false);
            }
            if (_submitted && !state.working && state.error == null) {
              _submitted = false;
              setState(() => _localSubmitting = false);
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            final disabled =
                state.working || _localSubmitting || _selectedIds.isEmpty;
            return ElevatedButton.icon(
              icon: disabled && (state.working || _localSubmitting)
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                  'فتح العقد${_selectedIds.isNotEmpty ? " (${_selectedIds.length})" : ""}'),
              onPressed: disabled
                  ? null
                  : () async {
                      if (_clientId == null) return;
                      if (!_formKey.currentState!.validate()) return;

                      // ✅ Credit limit check
                      final selectedClient =
                          _clients.cast<Client?>().firstWhere(
                                (c) => c?.id == _clientId,
                                orElse: () => null,
                              );

                      if (selectedClient != null &&
                          selectedClient.isFrozen == 1) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'هذا العميل مجمّد ولا يمكن فتح عقد له'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedClient != null &&
                          selectedClient.isOverCreditLimit) {
                        if (!context.mounted) return;
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 48),
                            title: const Text('تجاوز الحد الائتماني'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('العميل: ${selectedClient.name}'),
                                const SizedBox(height: 8),
                                Text(
                                    'الحد الائتماني: ${selectedClient.creditLimit.toStringAsFixed(0)} ${AppConfig.currencySymbol}'),
                                Text(
                                  'إجمالي الدين الحالي: ${selectedClient.totalDebt.toStringAsFixed(0)} ${AppConfig.currencySymbol}',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                    'يرجى تسديد المبلغ الآجل أو إضافة دفعة قبل فتح عقد جديد.'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('إلغاء'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context, false);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClientDetailsPage(
                                          client: selectedClient),
                                    ),
                                  );
                                },
                                icon:
                                    const Icon(Icons.person_search_outlined),
                                label: const Text('الذهاب لصفحة العميل'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.orange),
                                child: const Text('المتابعة رغم التحذير'),
                              ),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                      }

                      setState(() {
                        _localSubmitting = true;
                        _submitted = true;
                      });

                      // Build items list in the SAME format the API expects
                      final itemsList = _selectedIds.map((eqId) {
                        final rateText =
                            _rateControllers[eqId]?.text.trim() ?? '';
                        final notesText =
                            _notesControllers[eqId]?.text.trim() ?? '';
                        return <String, dynamic>{
                          'equipment_id': eqId,
                          if (rateText.isNotEmpty)
                            'rate': double.tryParse(rateText),
                          if (notesText.isNotEmpty) 'notes': notesText,
                        };
                      }).toList();

                      context.read<RentsBloc>().add(
                            RentOpened(
                              clientId: _clientId!,
                              items: itemsList,
                              startDatetime: nowSql(),
                            ),
                          );
                    },
            );
          },
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isActive = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isActive,
      onSelected: (_) => _onStatusFilterChanged(value),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEquipmentList() {
    final items = _filteredSortedEquipment;

    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد معدات مطابقة', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final eq = items[index];
        final isSelected = _selectedIds.contains(eq.id);
        final selectable = _isSelectable(eq);

        return _buildEquipmentTile(eq, isSelected, selectable);
      },
    );
  }

  Widget _buildEquipmentTile(
      Equipment eq, bool isSelected, bool selectable) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade50
            : selectable
                ? Colors.white
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? Colors.blue.shade300
              : selectable
                  ? Colors.grey.shade300
                  : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Main row: Checkbox + equipment info ──
          InkWell(
            onTap: selectable
                ? () => _toggleEquipment(eq.id, !isSelected)
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: selectable
                        ? (val) =>
                            _toggleEquipment(eq.id, val ?? false)
                        : null,
                    activeColor: Colors.blue,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        _statusColor(eq.status).withValues(alpha: 0.15),
                    child: Icon(
                      Icons.precision_manufacturing,
                      size: 16,
                      color: _statusColor(eq.status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eq.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: selectable
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${eq.serialNo ?? "-"} • ${eq.dailyRate.toStringAsFixed(0)} ${AppConfig.currencySymbol}/يوم',
                          style: TextStyle(
                            fontSize: 11,
                            color: selectable
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(eq.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      selectable
                          ? _statusLabel(eq.status)
                          : _unavailableReason(eq),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(eq.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details when selected ──
          if (isSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 0, 12, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _rateCtrl(eq.id, eq.dailyRate),
                      validator: validateRate,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'السعر اليومي',
                        hintText: eq.dailyRate.toStringAsFixed(0),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _notesCtrl(eq.id),
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionAgendaItem {
  const _CollectionAgendaItem({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.equipmentName,
    required this.status,
    required this.remainingAmount,
    this.latestCreatedAt,
    this.latestCreatedByName,
    this.latestNextFollowupAt,
    this.todayCreatedAt,
    this.todayCreatedByName,
  });

  final int id;
  final int clientId;
  final String clientName;
  final String equipmentName;
  final String status;
  final double remainingAmount;
  final String? latestCreatedAt;
  final String? latestCreatedByName;
  final String? latestNextFollowupAt;
  final String? todayCreatedAt;
  final String? todayCreatedByName;

  factory _CollectionAgendaItem.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    double toD(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

    return _CollectionAgendaItem(
      id: toI(json['id']),
      clientId: toI(json['client_id']),
      clientName: (json['client_name'] ?? '-').toString(),
      equipmentName: (json['equipment_name'] ?? '-').toString(),
      status: (json['status'] ?? '').toString(),
      remainingAmount: toD(json['remaining_amount']),
      latestCreatedAt: json['latest_created_at']?.toString(),
      latestCreatedByName: json['latest_created_by_name']?.toString(),
      latestNextFollowupAt: json['latest_next_followup_at']?.toString(),
      todayCreatedAt: json['today_created_at']?.toString(),
      todayCreatedByName: json['today_created_by_name']?.toString(),
    );
  }

  bool get hasContactToday =>
      todayCreatedAt != null && todayCreatedAt!.isNotEmpty;

  DateTime? get _nextFollowupDateTime => _parse(latestNextFollowupAt);

  bool get hasScheduledFollowupToday {
    final dt = _nextFollowupDateTime;
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool get hasUpcomingScheduledFollowup {
    final dt = _nextFollowupDateTime;
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.isAfter(DateTime(now.year, now.month, now.day));
  }

  String get todayCreatedAtLabel => _fmt(todayCreatedAt);
  String get latestCreatedAtLabel => _fmt(latestCreatedAt);
  String get nextFollowupAtLabel => _fmtFull(latestNextFollowupAt);

  static DateTime? _parse(String? value) {
    return DateTimeUtils.parse(value);
  }

  static String _fmt(String? value) {
    if (value == null || value.isEmpty) return '-';
    final dt = _parse(value);
    if (dt == null) return value;
    return DateTimeUtils.formatTime(dt);
  }

  static String _fmtFull(String? value) {
    if (value == null || value.isEmpty) return '-';
    final dt = _parse(value);
    if (dt == null) return value;
    return DateTimeUtils.format(dt);
  }
}



class QuickCloseResult {
  const QuickCloseResult({
    required this.paidAmount,
    required this.paymentMethod,
    required this.applySpecialPricing,
    this.paymentNotes,
    this.discountAmount = 0,
    this.discountNote,
  });

  final double paidAmount;
  final String paymentMethod;
  final bool applySpecialPricing;
  final String? paymentNotes;
  final double discountAmount;
  final String? discountNote;
}

class QuickCloseDialog extends StatefulWidget {
  const QuickCloseDialog({
    required this.rent,
    required this.settings,
    required this.totalAmount,
    required this.currentPaid,
    required this.remainingAmount,
  });

  final Rent rent;
  final dynamic settings;
  final double totalAmount;
  final double currentPaid;
  final double remainingAmount;

  @override
  State<QuickCloseDialog> createState() => QuickCloseDialogState();
}

class QuickCloseDialogState extends State<QuickCloseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _discountCtrl;
  final _discountNoteCtrl = TextEditingController();
  late final TextEditingController _notesCtrl;
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(text: '');
    _amountCtrl = TextEditingController(text: _requiredNow().round().toString());
    _discountCtrl.addListener(_applyDiscountToPaidAmount);
    _notesCtrl = TextEditingController();
  }

  double _discountValue() {
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    return discount.clamp(0, widget.totalAmount).toDouble();
  }

  double _requiredNow() {
    final netTotal = (widget.totalAmount - _discountValue()).clamp(0, widget.totalAmount).toDouble();
    final remaining = netTotal - widget.currentPaid;
    return remaining > 0 ? remaining : 0;
  }

  void _applyDiscountToPaidAmount() {
    if (_method != 'deferred') {
      _amountCtrl.text = _requiredNow().round().toString();
    }
  }

  double get _dailyRateSum {
    if (widget.rent.items.isEmpty) return widget.rent.rate ?? 0;
    return widget.rent.items.fold(0.0, (sum, item) => sum + (item.rate ?? 0));
  }

  void _applyDiscountPreset(String preset) {
    double discount = 0;
    final total = widget.totalAmount;
    final rate = _dailyRateSum > 0 ? _dailyRateSum : total;
    
    switch (preset) {
      case 'نصف المتبقي':
        final rem = total - widget.currentPaid;
        discount = rem / 2;
        break;
      case '30% من اليوم':
        discount = rate * 0.3;
        break;
      case 'ثلثي اليوم':
        discount = rate * (2 / 3);
        break;
      case 'بدون خصم':
        discount = 0;
        break;
    }
    
    if (discount > total) discount = total;
    if (discount < 0) discount = 0;
    
    _discountCtrl.text = discount > 0 ? discount.toStringAsFixed(2) : '';
    _discountNoteCtrl.text = discount > 0 ? preset : '';
    // _applyDiscountToPaidAmount is called via listener
  }

  @override
  void dispose() {
    _discountCtrl.removeListener(_applyDiscountToPaidAmount);
    _amountCtrl.dispose();
    _discountCtrl.dispose();
    _discountNoteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalAmount;
    final isDeferred = _method == 'deferred';

    return AlertDialog(
      title: const Text('تسديد وإغلاق العقد'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي العقد الأساسي: ${total.round()} ${AppConfig.currencySymbol}'),
                      Text('المدفوع سابقًا: ${widget.currentPaid.round()} ${AppConfig.currencySymbol}'),
                      Text('المتبقي الحالي (قبل الخصم): ${(total - widget.currentPaid).round()} ${AppConfig.currencySymbol}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: Text('خيارات الاحتساب الخاص:', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => _applyDiscountPreset('نصف المتبقي'), child: const Text('نصف المتبقي')),
                    OutlinedButton(onPressed: () => _applyDiscountPreset('30% من اليوم'), child: const Text('30% من اليوم')),
                    OutlinedButton(onPressed: () => _applyDiscountPreset('ثلثي اليوم'), child: const Text('ثلثي اليوم')),
                    OutlinedButton(onPressed: () => _applyDiscountPreset('بدون خصم'), child: const Text('بدون خصم')),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الخصم الفعلي (يدوي أو تلقائي)',
                    helperText: 'يُخصم من إجمالي العقد الأساسي',
                    border: OutlineInputBorder(),
                    prefixText: '${AppConfig.currencySymbol} ',
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    final n = double.tryParse(text);
                    if (n == null || n < 0) return 'أدخل خصمًا صحيحًا';
                    if (n > widget.totalAmount) return 'الخصم لا يمكن أن يتجاوز الإجمالي';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountNoteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'سبب الخصم', border: OutlineInputBorder()),
                  validator: (v) {
                    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
                    if (discount > 0 && (v ?? '').trim().isEmpty) {
                      return 'اكتب سبب الخصم';
                    }
                    return null;
                  },
                ),
                const Divider(height: 32),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                    DropdownMenuItem(value: 'deferred', child: Text('آجل')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _method = v ?? 'cash';
                      if (_method == 'deferred') {
                        _amountCtrl.text = '0';
                      } else {
                        _applyDiscountToPaidAmount();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  readOnly: isDeferred,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المسدد الآن', 
                    border: const OutlineInputBorder(), 
                    prefixText: '${AppConfig.currencySymbol} ',
                    fillColor: isDeferred ? Colors.grey.shade200 : null,
                    filled: isDeferred,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'أدخل مبلغًا صحيحًا';
                    final required = _requiredNow();
                    if (!isDeferred && required > 0 && n - required > 0.009) {
                      return 'المبلغ أكبر من المطلوب: ${required.round()} ${AppConfig.currencySymbol}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة عامة على الدفعة (اختياري)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, QuickCloseResult(
              paidAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
              paymentMethod: _method,
              applySpecialPricing: false, // Legacy, no longer used
              paymentNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
              discountNote: _discountNoteCtrl.text.trim().isEmpty ? null : _discountNoteCtrl.text.trim(),
            ));
          },
          child: const Text('تأكيد الإغلاق'),
        ),
      ],
    );
  }
}
