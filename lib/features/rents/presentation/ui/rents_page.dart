import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/rents/presentation/bloc/rents_bloc.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';

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
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

double safeRentPaid(Rent rent) {
  final paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
  return paid < 0 ? 0 : paid;
}

double safeRentTotal(Rent rent) {
  if ((rent.totalAmount ?? 0) > 0) return rent.totalAmount!;

  final status = (rent.status ?? '').toLowerCase();
  if (status != 'open') return 0;

  final dailyRate = rent.rate ?? 0;
  final start = _tryParseRentDate(rent.startDatetime);
  if (dailyRate <= 0 || start == null) return 0;

  final now = DateTime.now();
  final minutes = now.difference(start).inMinutes;
  if (minutes <= 0) return 0;

  final hours = minutes / 60.0;

  double total;
  if (hours < 3) {
    total = dailyRate * (2 / 3);
  } else {
    total = dailyRate;
  }

  return double.parse(total.toStringAsFixed(2));
}

double safeRentRemaining(Rent rent) {
  final direct = rent.remainingAmount;
  if (direct != null) {
    return direct < 0 ? 0 : direct;
  }

  final total = safeRentTotal(rent);
  final paid = safeRentPaid(rent);
  final remaining = total - paid;
  return remaining > 0 ? remaining : 0;
}

class RentsPage extends StatelessWidget {
  const RentsPage({super.key});

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
      ],
      child: BlocProvider(
        create: (context) =>
            RentsBloc(context.read<RentsRepository>())
              ..add(const RentsRequested()),
        child: _RentsView(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

class _RentsView extends StatefulWidget {
  const _RentsView({this.showBackButton = true});
  final bool showBackButton;

  @override
  State<_RentsView> createState() => _RentsViewState();
}

class _RentsViewState extends State<_RentsView> {
  String _statusFilter = 'all';
  String _query = '';
  String _collectionSort = 'oldest';

  bool _loadingAgenda = false;
  List<_CollectionAgendaItem> _agendaItems = const [];

  @override
  void initState() {
    super.initState();
    _fetchCollectionAgenda();
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
      case 'open':
      case 'closed':
      case 'cancelled':
        return _statusFilter;
      default:
        return null;
    }
  }

  Future<void> _reloadEverything() async {
    if (!mounted) return;
    context.read<RentsBloc>().add(RentsRequested(status: _statusParam));
    await _fetchCollectionAgenda();
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

  List<Rent> _applyUiFilters(List<Rent> items) {
    final q = _query.trim().toLowerCase();

    return items.where((rent) {
      final status = (rent.status ?? '').toLowerCase();
      final reviewNeeded = _needsReview(rent);
      final overdue = _isOverdue(rent);
      final closedUnpaid = _isClosedWithDeferredPayment(rent);

      final passesStatus = switch (_statusFilter) {
        'all' => true,
        'open' => status == 'open',
        'closed' => status == 'closed',
        'cancelled' => status == 'cancelled',
        'review' => reviewNeeded,
        'overdue' => overdue,
        'deferred' => closedUnpaid,
        _ => true,
      };

      if (!passesStatus) return false;
      if (q.isEmpty) return true;

      final total = safeRentTotal(rent);
      final paid = safeRentPaid(rent);
      final remaining = safeRentRemaining(rent);

      final haystack = [
        rent.id.toString(),
        rent.clientName ?? '',
        rent.equipmentName ?? '',
        rent.startDatetime,
        rent.endDatetime ?? '',
        rent.closingPaymentId?.toString() ?? '',
        rent.pricingRuleLabel ?? '',
        total.toStringAsFixed(2),
        paid.toStringAsFixed(2),
        remaining.toStringAsFixed(2),
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  bool _isOverdue(Rent rent) {
    final status = (rent.status ?? '').toLowerCase();
    if (status != 'open') return false;
    final start = _tryParseRentDate(rent.startDatetime);
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!)),
              );
            }
          },
          builder: (context, state) {
            if (state.status == RentsStatus.loading) {
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
                        Text(
                          'إدارة العقود اليومية',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اعرض العقود المفتوحة والمغلقة بسرعة، وراجع العقود المتأخرة أو التي أغلقت بدون سند قبض.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
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
                  if (stats.overdue > 0 || stats.deferredCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (stats.overdue > 0 ? Colors.red : Colors.orange)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (stats.overdue > 0 ? Colors.red : Colors.orange)
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            stats.overdue > 0
                                ? Icons.warning_amber_rounded
                                : Icons.account_balance_wallet_outlined,
                            color:
                                stats.overdue > 0 ? Colors.red : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stats.overdue > 0
                                      ? 'لديك عقود متأخرة تحتاج متابعة الآن'
                                      : 'هناك عقود مغلقة لكن ما زال عليها رصيد مؤجل',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المتأخرة: ${stats.overdue} • المؤجلة: ${stats.deferredCount} • المتبقي: ${stats.deferredAmount.toStringAsFixed(2)} ر.س',
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
                            onPressed: () => setState(
                              () => _statusFilter =
                                  stats.overdue > 0 ? 'overdue' : 'deferred',
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('عرض الآن'),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 108,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'كل العقود',
                          value: stats.total.toString(),
                          icon: Icons.assignment_outlined,
                          tone: colorScheme.primary,
                        ),
                        _StatCard(
                          title: 'مفتوحة',
                          value: stats.open.toString(),
                          icon: Icons.lock_open_rounded,
                          tone: Colors.blue,
                        ),
                        _StatCard(
                          title: 'متأخرة',
                          value: stats.overdue.toString(),
                          icon: Icons.warning_amber_rounded,
                          tone: Colors.red,
                        ),
                        _StatCard(
                          title: 'تسديد مؤجل',
                          value: stats.deferredCount.toString(),
                          icon: Icons.account_balance_wallet_outlined,
                          tone: Colors.orange,
                          subtitle:
                              '${stats.deferredAmount.toStringAsFixed(0)} ر.س',
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
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
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
                                              : Icons.account_balance_wallet_outlined,
                                          color: item.hasContactToday
                                              ? Colors.blue
                                              : Colors.orange,
                                        ),
                                      ),
                                      title: Text(
                                        'عقد #${item.id} • ${item.clientName}',
                                      ),
                                      subtitle:
                                          Text(_collectionAgendaSubtitle(item)),
                                      isThreeLine: true,
                                      trailing:
                                          const Icon(Icons.chevron_left),
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
                              onPressed: () =>
                                  setState(() => _statusFilter = 'deferred'),
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
                        onTap: () => setState(() => _statusFilter = 'all'),
                      ),
                      _FilterChip(
                        label: 'مفتوحة',
                        selected: _statusFilter == 'open',
                        onTap: () => setState(() => _statusFilter = 'open'),
                      ),
                      _FilterChip(
                        label: 'مغلقة',
                        selected: _statusFilter == 'closed',
                        onTap: () => setState(() => _statusFilter = 'closed'),
                      ),
                      _FilterChip(
                        label: 'ملغاة',
                        selected: _statusFilter == 'cancelled',
                        onTap: () => setState(() => _statusFilter = 'cancelled'),
                      ),
                      _FilterChip(
                        label: 'متأخرة',
                        selected: _statusFilter == 'overdue',
                        onTap: () => setState(() => _statusFilter = 'overdue'),
                      ),
                      _FilterChip(
                        label: 'بحاجة مراجعة',
                        selected: _statusFilter == 'review',
                        onTap: () => setState(() => _statusFilter = 'review'),
                      ),
                      _FilterChip(
                        label: 'تسديد مؤجل',
                        selected: _statusFilter == 'deferred',
                        onTap: () => setState(() => _statusFilter = 'deferred'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'العقود المعروضة',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${filtered.length} نتيجة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                  else
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
                          onCancelled: (rentId) {
                            context.read<RentsBloc>().add(
                                  RentCancelled(rentId: rentId),
                                );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _collectionAgendaSubtitle(_CollectionAgendaItem item) {
    final lines = <String>[
      'المتبقي: ${item.remainingAmount.toStringAsFixed(2)} ر.س'
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
}

class _RentCard extends StatelessWidget {
  const _RentCard({
    required this.rent,
    required this.isOverdue,
    required this.needsReview,
    required this.isClosedWithDeferredPayment,
    required this.remainingAmount,
    required this.onOpenDetails,
    required this.onCancelled,
  });

  final Rent rent;
  final bool isOverdue;
  final bool needsReview;
  final bool isClosedWithDeferredPayment;
  final double remainingAmount;
  final VoidCallback onOpenDetails;
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

    final financialHint = remaining > 0.009
        ? 'متبقٍ على العميل ${remaining.toStringAsFixed(2)} ر.س'
        : (rent.pricingRuleLabel ?? 'الاحتساب القياسي');

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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rent.clientName ?? 'عميل غير محدد',
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
                            : '${total.toStringAsFixed(2)} ر.س',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniMetric(
                        label: remaining > 0.009 ? 'المتبقي' : 'المدفوع',
                        value: remaining > 0.009
                            ? '${remaining.toStringAsFixed(2)} ر.س'
                            : '${paid.toStringAsFixed(2)} ر.س',
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
                          onPressed: onOpenDetails,
                          icon: Icon(
                            isClosed
                                ? Icons.receipt_long
                                : Icons.lock_clock_outlined,
                          ),
                          label: Text(isClosed ? 'مراجعة الإغلاق' : 'إغلاق سريع'),
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
                            content:
                                Text('هل تريد إلغاء العقد رقم #${rent.id} ؟'),
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
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsetsDirectional.only(end: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tone.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tone,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tone,
                      fontSize: 10,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
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
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
            ),
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
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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
  List<Equipment> _equipment = [];

  int? _clientId;
  int? _equipmentId;

  final _rateCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _submitted = false;
  bool _localSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.clientsRepo.list();
    final e = await widget.equipmentRepo.list();

    if (!mounted) return;

    final availableEquipment =
        e.where((x) => (x.status ?? 'available') != 'rented').toList();

    setState(() {
      _clients = c;
      _equipment = availableEquipment;
      _clientId = _clients.isNotEmpty ? _clients.first.id : null;
      _equipmentId = _equipment.isNotEmpty ? _equipment.first.id : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فتح عقد'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownSearch<Client>(
                    items: (filter, _) => _clients
                        .where(
                          (c) =>
                              c.name
                                  .toLowerCase()
                                  .contains(filter.toLowerCase()) ||
                              (c.phone != null && c.phone!.contains(filter)) ||
                              (c.nationalId != null &&
                                  c.nationalId!.contains(filter)),
                        )
                        .toList(),
                    compareFn: (i, s) => i.id == s.id,
                    itemAsString: (Client c) => '${c.id} - ${c.name}',
                    selectedItem: _clients.isNotEmpty
                        ? _clients.firstWhere(
                            (c) => c.id == _clientId,
                            orElse: () => _clients.first,
                          )
                        : null,
                    onChanged: (Client? data) {
                      if (data != null) setState(() => _clientId = data.id);
                    },
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'العميل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم، رقم الجوال، أو الهوية...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemBuilder: (context, item, isDisabled, isSelected) =>
                          ListTile(
                        title: Text(item.name),
                        subtitle:
                            Text('${item.phone ?? ""} | ${item.nationalId ?? ""}'),
                        selected: isSelected,
                        trailing: Text('#${item.id}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownSearch<Equipment>(
                    items: (filter, _) => _equipment
                        .where(
                          (e) =>
                              e.name
                                  .toLowerCase()
                                  .contains(filter.toLowerCase()) ||
                              (e.serialNo != null &&
                                  e.serialNo!
                                      .toLowerCase()
                                      .contains(filter.toLowerCase())),
                        )
                        .toList(),
                    compareFn: (i, s) => i.id == s.id,
                    itemAsString: (Equipment e) =>
                        '${e.name} - ${e.serialNo ?? "-"}',
                    selectedItem: _equipment.isNotEmpty
                        ? _equipment.firstWhere(
                            (e) => e.id == _equipmentId,
                            orElse: () => _equipment.first,
                          )
                        : null,
                    onChanged: (Equipment? data) {
                      if (data != null) setState(() => _equipmentId = data.id);
                    },
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'المعدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم المعدة أو الرقم التسلسلي...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      itemBuilder: (context, item, isDisabled, isSelected) =>
                          ListTile(
                        title: Text(item.name),
                        subtitle: Text('رقم تسلسلي: ${item.serialNo ?? "-"}'),
                        selected: isSelected,
                        trailing: Text('#${item.id}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateCtrl,
                    validator: validateRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'سعر اليومي  (اتياري)خ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
            final disabled = state.working || _localSubmitting;
            return ElevatedButton(
              onPressed: disabled
                  ? null
                  : () {
                      if (_clientId == null || _equipmentId == null) return;
                      if (!_formKey.currentState!.validate()) return;

                      setState(() {
                        _localSubmitting = true;
                        _submitted = true;
                      });

                      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;

                      context.read<RentsBloc>().add(
                            RentOpened(
                              clientId: _clientId!,
                              equipmentId: _equipmentId!,
                              startDatetime: nowSql(),
                              dailyRate: rate,
                            ),
                          );
                    },
              child: disabled
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('فتح'),
            );
          },
        ),
      ],
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
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  static String _fmt(String? value) {
    if (value == null || value.isEmpty) return '-';
    final dt = _parse(value);
    if (dt == null) return value;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _fmtFull(String? value) {
    if (value == null || value.isEmpty) return '-';
    final dt = _parse(value);
    if (dt == null) return value;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}