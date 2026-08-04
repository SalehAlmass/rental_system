import 'dart:async';
import 'package:rental_app/core/utils/debouncer.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/core/widgets/permission_guard.dart';
import 'package:rental_app/core/printing/pdf_service.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';
import 'package:rental_app/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/features/payments/presentation/ui/payment_details_page.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

String? validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال المبلغ';
  final v = double.tryParse(value.trim());
  if (v == null || v <= 0) return 'الرجاء إدخال مبلغ صحيح';
  return null;
}

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => PaymentsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => ClientsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => RentsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => EquipmentRepository(context.read<ApiClient>()),
        ),
      ],
      child: BlocProvider(
        create: (context) =>
            PaymentsBloc(context.read<PaymentsRepository>())
              ..add(const PaymentsRequested()),
        child: _PaymentsView(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

class _PaymentsView extends StatefulWidget {
  const _PaymentsView({required this.showBackButton});
  final bool showBackButton;

  @override
  State<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<_PaymentsView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final state = context.read<PaymentsBloc>().state;
      context.read<PaymentsBloc>().add(
        PaymentsRequested(
          showVoided: state.showVoided,
          query: query.trim().isNotEmpty ? query.trim() : null,
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomAppBar(
                title: 'السندات',
                onIconPressed: widget.showBackButton
                    ? () => Navigator.pop(context)
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                    onPressed: () {
                      final state = context.read<PaymentsBloc>().state;
                      context.read<PaymentsBloc>().add(
                        PaymentsRequested(showVoided: state.showVoided),
                      );
                    },
                  ),
                  BlocBuilder<PaymentsBloc, PaymentsState>(
                    builder: (context, state) {
                      return IconButton(
                        tooltip: state.showVoided
                            ? 'إخفاء الملغية'
                            : 'إظهار الملغية',
                        icon: Icon(
                          state.showVoided
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          context.read<PaymentsBloc>().add(
                            PaymentsRequested(showVoided: !state.showVoided),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              Material(
                color: cs.primary,
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'سندات العقود'),
                    Tab(text: 'سندات عامة'),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'payments_fab',
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('إضافة سند'),
          onPressed: () => _openDialog(context),
        ),
        body: PageEntrance(
          child: BlocConsumer<PaymentsBloc, PaymentsState>(
            listener: (context, state) {
              if (state.error != null && state.error!.isNotEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            builder: (context, state) {
              if (state.status == PaymentsStatus.loading &&
                  state.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final filtered = _applyCommonFilters(state.items);
              final summary = state.summary != null
                  ? _PaymentsSummary.fromServer(state.summary!, state.total)
                  : _PaymentsSummary.from(filtered);

              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        context.read<PaymentsBloc>().add(
                          PaymentsRequested(showVoided: state.showVoided),
                        );
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          _PaymentsHeader(summary: summary),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText:
                                  'ابحث برقم السند، العميل، العقد أو الملاحظة',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    ),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'الكل',
                                value: 'all',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'قبض',
                                value: 'in',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'صرف',
                                value: 'out',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'مرتبطة بعقد',
                                value: 'rent',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'صيانة معدات',
                                value: 'equipment',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'ملغية',
                                value: 'void',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                              _FilterChip(
                                label: 'اليوم',
                                value: 'today',
                                groupValue: _selectedFilter,
                                onSelected: _setFilter,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.point_of_sale_rounded,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'هذه الشاشة مرتبطة بالمراجعة اليومية للصندوق. كل سند قبض أو صرف ينعكس على إغلاق الدوام ومقارنة المقبوض الفعلي بالمفترض.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildSortingBar(context, state),
                          SizedBox(
                            height: MediaQuery.of(context).size.height,
                            child: TabBarView(
                              children: [
                                _PaymentsList(
                                  scope: _PaymentsScope.rent,
                                  allItems: filtered,
                                  query: _searchController.text,
                                  filter: _selectedFilter,
                                  onEdit: (p) => _openDialog(context, edit: p),
                                  onVoid: (p) => _confirmVoid(context, p),
                                ),
                                _PaymentsList(
                                  scope: _PaymentsScope.general,
                                  allItems: filtered,
                                  query: _searchController.text,
                                  filter: _selectedFilter,
                                  onEdit: (p) => _openDialog(context, edit: p),
                                  onVoid: (p) => _confirmVoid(context, p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSortingBar(BuildContext context, PaymentsState state) {
    final bloc = context.read<PaymentsBloc>();
    final currentSortBy = state.sortBy ?? 'id';
    final currentSortOrder = state.sortOrder ?? 'desc';

    final sortOptions = {
      'id': 'رقم السند',
      'created_at': 'تاريخ السند',
      'amount': 'المبلغ',
      'type': 'نوع السند',
      'client_name': 'اسم العميل',
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
                bloc.add(PaymentsRequested(
                  showVoided: state.showVoided,
                  query: state.query,
                  page: state.page,
                  perPage: state.perPage,
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
              bloc.add(PaymentsRequested(
                showVoided: state.showVoided,
                query: state.query,
                page: state.page,
                perPage: state.perPage,
                sortBy: currentSortBy,
                sortOrder: nextOrder,
              ));
            },
          ),
        ],
      ),
    );
  }

  void _setFilter(String value) {
    setState(() => _selectedFilter = value);
    final state = context.read<PaymentsBloc>().state;
    context.read<PaymentsBloc>().add(
      PaymentsRequested(
        showVoided: state.showVoided,
        query: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      ),
    );
  }

  List<Payment> _applyCommonFilters(List<Payment> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return items.where((p) {
      switch (_selectedFilter) {
        case 'today':
          final dt = DateTime.tryParse(p.createdAt ?? '');
          if (dt == null) return false;
          final d = DateTime(dt.year, dt.month, dt.day);
          return d == today;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _openDialog(BuildContext context, {Payment? edit}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<PaymentsBloc>(),
        child: _PaymentDialog(
          edit: edit,
          clientsRepo: context.read<ClientsRepository>(),
          rentsRepo: context.read<RentsRepository>(),
          equipmentRepo: context.read<EquipmentRepository>(),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      context.read<PaymentsBloc>().add(
        PaymentsRequested(
          showVoided: context.read<PaymentsBloc>().state.showVoided,
        ),
      );
    }
  }

  Future<void> _confirmVoid(BuildContext context, Payment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل تريد إلغاء السند رقم #${p.id}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء السند'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.read<PaymentsBloc>().add(PaymentVoided(id: p.id));
    }
  }
}

enum _PaymentsScope { rent, general }

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({
    required this.scope,
    required this.allItems,
    required this.query,
    required this.filter,
    required this.onEdit,
    required this.onVoid,
  });

  final _PaymentsScope scope;
  final List<Payment> allItems;
  final String query;
  final String filter;
  final void Function(Payment p) onEdit;
  final void Function(Payment p) onVoid;

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems();

    if (items.isEmpty) {
      return _PaymentsEmptyState(scope: scope);
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _PaymentCard(payment: items[index], onEdit: onEdit, onVoid: onVoid),
    );
  }

  List<Payment> _filteredItems() {
    final q = query.trim().toLowerCase();
    return allItems.where((p) {
      final hasRent = (p.rentId != null) && (p.rentId != 0);
      final scopeMatch = scope == _PaymentsScope.rent ? hasRent : !hasRent;
      if (!scopeMatch) return false;

      bool filterMatch = true;
      if (filter == 'in') {
        filterMatch = p.type.toLowerCase() == 'in';
      } else if (filter == 'out') {
        filterMatch = p.type.toLowerCase() == 'out';
      } else if (filter == 'rent') {
        filterMatch = (p.rentId ?? 0) > 0;
      } else if (filter == 'equipment') {
        filterMatch = (p.equipmentId ?? 0) > 0;
      } else if (filter == 'void') {
        filterMatch = p.isVoid;
      }

      if (!filterMatch) return false;

      if (q.isEmpty) return true;
      final haystack = [
        '${p.id}',
        p.clientName ?? '',
        '${p.rentNo ?? ''}',
        p.notes ?? '',
        p.referenceNo ?? '',
        p.method ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({required this.summary});
  final _PaymentsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.surfaceContainerHighest],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة السندات والمقبوضات',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'سندات القبض والصرف هنا هي المصدر اليومي لحركة الصندوق، وربط العقود والصيانة والمراجعة المحاسبية.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryCard(
                label: 'إجمالي القبض',
                value: summary.totalIn,
                icon: Icons.south_west_rounded,
              ),
              _SummaryCard(
                label: 'إجمالي الصرف',
                value: summary.totalOut,
                icon: Icons.north_east_rounded,
              ),
              _SummaryCard(
                label: 'صافي الحركة',
                value: summary.net,
                icon: Icons.account_balance_wallet_outlined,
                highlight: summary.netValue < 0,
              ),
              _SummaryCard(
                label: 'عدد السندات',
                value: '${summary.count}',
                icon: Icons.receipt_long_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? cs.errorContainer : cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? cs.onErrorContainer : cs.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: value == groupValue,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.onEdit,
    required this.onVoid,
  });
  final Payment payment;
  final void Function(Payment p) onEdit;
  final void Function(Payment p) onVoid;

  @override
  Widget build(BuildContext context) {
    final pstate = context.watch<ProfileCubit>().state;
    final canPrint = pstate.hasScreenPermission('print');
    final canEdit = pstate.hasActionPermission('payments', 'edit');
    final canVoid = pstate.hasActionPermission('payments', 'void');
    final isIn = payment.type.toLowerCase() == 'in';
    final cs = Theme.of(context).colorScheme;
    final stateColor = payment.isVoid
        ? Colors.grey
        : (isIn ? Colors.green : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PaymentDetailsPage(payment: payment, paymentId: payment.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: stateColor,
                    child: Icon(
                      isIn
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سند #${payment.id}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.isVoid
                              ? 'سند ملغي'
                              : ((payment.equipmentId ?? 0) > 0 &&
                                    payment.type.toLowerCase() == 'out')
                              ? 'سند صيانة معدة'
                              : (isIn ? 'سند قبض' : 'سند صرف'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(payment: payment),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.payments_outlined,
                    text: '${payment.amount.round()} ${AppConfig.currencySymbol}',
                  ),
                  _MetaChip(
                    icon: Icons.person_outline_rounded,
                    text: payment.clientName ?? 'بدون عميل',
                  ),
                  _MetaChip(
                    icon: Icons.description_outlined,
                    text: payment.rentNo != null
                        ? 'عقد #${payment.rentNo}'
                        : 'غير مرتبط بعقد',
                  ),
                  _MetaChip(
                    icon: Icons.account_balance_outlined,
                    text: _methodLabel(payment.method),
                  ),
                  if ((payment.equipmentId ?? 0) > 0)
                    const _MetaChip(
                      icon: Icons.build_circle_outlined,
                      text: 'صيانة معدة',
                    ),
                  if (payment.userName != null && payment.userName!.isNotEmpty)
                    _MetaChip(
                      icon: Icons.badge_outlined,
                      text: 'بواسطة: ${payment.userName}',
                    ),
                ],
              ),
              if ((payment.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  payment.notes!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(payment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (canPrint) ...[
                    IconButton(
                      tooltip: 'طباعة السند',
                      icon: const Icon(Icons.print_outlined),
                      onPressed: () async {
                        try {
                          await PdfService().printPaymentVoucher(
                            payment: payment,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الطباعة: $e')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'مشاركة PDF',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () async {
                        try {
                          await PdfService().sharePaymentVoucher(
                            payment: payment,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل المشاركة: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                  if (!payment.isVoid) ...[
                    if (canEdit)
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEdit(payment),
                      ),
                    if (canVoid)
                      IconButton(
                        tooltip: 'إلغاء السند',
                        icon: const Icon(Icons.block_outlined),
                        color: Colors.red,
                        onPressed: () => onVoid(payment),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _methodLabel(String? method) {
    switch ((method ?? '').toLowerCase()) {
      case 'cash':
        return 'نقدي';
      case 'transfer':
      case 'bank':
        return 'تحويل بنكي';
      case 'card':
        return 'بطاقة';
      default:
        return method?.trim().isEmpty ?? true ? 'غير محدد' : method!;
    }
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'بدون تاريخ';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(dt);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isIn = payment.type.toLowerCase() == 'in';
    final label = payment.isVoid ? 'ملغي' : (isIn ? 'قبض' : 'صرف');
    final bg = payment.isVoid
        ? Colors.grey.shade300
        : (isIn ? Colors.green.shade100 : Colors.red.shade100);
    final fg = payment.isVoid
        ? Colors.black87
        : (isIn ? Colors.green.shade800 : Colors.red.shade800);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
      ),
    );
  }
}

class _PaymentsEmptyState extends StatelessWidget {
  const _PaymentsEmptyState({required this.scope});
  final _PaymentsScope scope;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            scope == _PaymentsScope.rent
                ? 'لا توجد سندات مرتبطة بالعقود'
                : 'لا توجد سندات عامة أو مصروفات حالياً',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك إضافة سند قبض، مصروف عام، أو قيد صيانة مرتبط بمعدة من زر الإضافة.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PaymentsSummary {
  const _PaymentsSummary({
    required this.count,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.netValue,
  });

  final int count;
  final String totalIn;
  final String totalOut;
  final String net;
  final double netValue;

  factory _PaymentsSummary.from(List<Payment> items) {
    double totalIn = 0;
    double totalOut = 0;
    for (final p in items) {
      if (p.isVoid) continue;
      if (p.type.toLowerCase() == 'in') {
        totalIn += p.amount;
      } else {
        totalOut += p.amount;
      }
    }
    final net = totalIn - totalOut;
    return _PaymentsSummary(
      count: items.length,
      totalIn: '${totalIn.round()} ${AppConfig.currencySymbol}',
      totalOut: '${totalOut.round()} ${AppConfig.currencySymbol}',
      net: '${net.round()} ${AppConfig.currencySymbol}',
      netValue: net,
    );
  }

  factory _PaymentsSummary.fromServer(PaymentSummary server, int count) {
    final net = server.totalIn - server.totalOut;
    return _PaymentsSummary(
      count: count,
      totalIn: '${server.totalIn.round()} ${AppConfig.currencySymbol}',
      totalOut: '${server.totalOut.round()} ${AppConfig.currencySymbol}',
      net: '${net.round()} ${AppConfig.currencySymbol}',
      netValue: net,
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.clientsRepo,
    required this.rentsRepo,
    required this.equipmentRepo,
    this.edit,
  });

  final ClientsRepository clientsRepo;
  final RentsRepository rentsRepo;
  final EquipmentRepository equipmentRepo;
  final Payment? edit;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'in';
  String _method = 'cash';
  int? _clientId;
  int? _rentId;
  int? _equipmentId;

  List<Client> _clients = [];
  List<Rent> _rents = [];
  List<Equipment> _equipments = [];
  bool _loading = true;

  bool _submitted = false;
  bool _localSubmitting = false;

  bool get _isOutVoucher => _type == 'out' || _type == 'depreciation';
  bool get _isMaintenanceVoucher => _isOutVoucher && (_equipmentId ?? 0) > 0;
  bool get _isDepreciationVoucher => _type == 'depreciation';

  @override
  void initState() {
    super.initState();
    final pstate = context.read<ProfileCubit>().state;
    final hasReceipts = pstate is ProfileLoaded && pstate.hasScreenPermission('receipts');
    _type = hasReceipts ? 'in' : 'out';

    final p = widget.edit;
    if (p != null) {
      _amount.text = p.amount.toString();
      _ref.text = p.referenceNo ?? '';
      _notes.text = p.notes ?? '';
      _type = p.type;
      _method = p.method ?? 'cash';
      _clientId = p.clientId;
      _rentId = p.rentId;
      _equipmentId = p.equipmentId;
    }
    _load();
  }

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

  Future<void> _load() async {
    final c = await widget.clientsRepo.list();
    final r = await widget.rentsRepo.list();
    final e = await widget.equipmentRepo.list();

    if (_clientId != null && !c.any((client) => client.id == _clientId)) {
      try {
        final selectedClient = await widget.clientsRepo.getById(_clientId!);
        c.insert(0, selectedClient);
      } catch (_) {}
    }

    if (_equipmentId != null && !e.any((eq) => eq.id == _equipmentId)) {
      try {
        final selectedEq = await widget.equipmentRepo.getById(_equipmentId!);
        e.add(selectedEq);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _clients = c;
      _rents = r;
      _equipments = e;
      _clientId ??= _clients.isNotEmpty ? _clients.first.id : null;
      _rentId ??= null;
      _equipmentId ??= null;
      _loading = false;
    });
  }

  String _equipmentNameById(int? id) {
    if (id == null) return '';
    final eq = _equipments.cast<Equipment?>().firstWhere(
      (e) => e?.id == id,
      orElse: () => null,
    );
    return eq?.name ?? 'المعدة #$id';
  }

  String _buildAutoMaintenanceNote() {
    final eqName = _equipmentNameById(_equipmentId);
    return _isDepreciationVoucher ? 'سند صرف إهلاك للمعدة: $eqName' : 'سند صيانة للمعدة: $eqName';
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    final pstate = context.read<ProfileCubit>().state;
    final hasPayments = pstate is ProfileLoaded && pstate.hasScreenPermission('payments');
    final hasReceipts = pstate is ProfileLoaded && pstate.hasScreenPermission('receipts');

    return AlertDialog(
      title: Text(editing ? 'تعديل سند' : 'إضافة سند'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!editing)
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'نوع السند',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          if (hasReceipts)
                            const DropdownMenuItem(value: 'in', child: Text('سند قبض')),
                          if (hasPayments)
                            const DropdownMenuItem(
                              value: 'out',
                              child: Text('سند صرف'),
                            ),
                          if (hasPayments)
                            const DropdownMenuItem(
                              value: 'depreciation',
                              child: Text('سند صرف إهلاك'),
                            ),
                        ],
                        onChanged: (v) {
                          final value = v ?? 'in';
                          setState(() {
                            _type = value;
                            if (_type == 'in') {
                              _equipmentId = null;
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 10),

                    if (_isOutVoucher)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color:
                              (_isMaintenanceVoucher
                                      ? Colors.orange
                                      : Colors.blue)
                                  .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (_isMaintenanceVoucher
                                        ? Colors.orange
                                        : Colors.blue)
                                    .withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          _isDepreciationVoucher
                              ? 'هذا السند سيُسجل كسند صرف إهلاك للمعدة'
                              : (_isMaintenanceVoucher
                                  ? 'هذا السند سيُسجل كسند صيانة معدة'
                                  : 'يمكنك جعل هذا السند مصروف صيانة أو إهلاك عبر اختيار المعدة أدناه'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                    TextFormField(
                      controller: _amount,
                      validator: validateAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownSearch<Client>(
                      suffixProps: const DropdownSuffixProps(
                        clearButtonProps: ClearButtonProps(
                          isVisible: true,
                        ),
                      ),
                      items: (filter, _) => _fetchClients(filter),
                      compareFn: (a, b) => a.id == b.id,
                      selectedItem: _clientId == null
                          ? null
                          : _clients.cast<Client?>().firstWhere((c) => c?.id == _clientId, orElse: () => null),
                      itemAsString: (c) => '${c.id} - ${c.name}',
                      onChanged: (Client? selected) {
                        setState(() {
                          _clientId = selected?.id;
                        });
                      },
                      decoratorProps: const DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'العميل (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchDelay: const Duration(milliseconds: 400),
                        searchFieldProps: const TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم، الجوال، الهوية أو الكود...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        itemBuilder: (context, item, isDisabled, isSelected) => ListTile(
                          title: Text(item.name),
                          subtitle: Text('${item.phone ?? ""} | ${item.nationalId ?? ""}'),
                          selected: isSelected,
                          trailing: Text('#${item.id}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownSearch<Rent>(
                      items: (filter, _) => _rents.where((r) {
                        final q = filter.toLowerCase();
                        final hay = 'عقد #${r.id} ${r.clientName ?? ''} ${r.equipmentName ?? ''}'.toLowerCase();
                        return hay.contains(q);
                      }).toList(),
                      compareFn: (a, b) => a.id == b.id,
                      selectedItem: _rentId == null
                          ? null
                          : _rents.cast<Rent?>().firstWhere((r) => r?.id == _rentId, orElse: () => null),
                      itemAsString: (r) => 'عقد #${r.id} - ${r.clientName ?? 'بدون عميل'}',
                      onChanged: (Rent? selected) {
                        setState(() {
                          _rentId = selected?.id;
                          if (selected != null) {
                            _clientId = selected.clientId;
                          }
                        });
                      },
                      decoratorProps: const DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'العقد (اختياري)',
                          border: OutlineInputBorder(),
                          helperText: 'ابحث برقم العقد وسيتم جلب العميل تلقائيًا',
                        ),
                      ),
                      popupProps: const PopupProps.menu(
                        showSearchBox: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<int?>(
                      initialValue: _equipmentId,
                      decoration: const InputDecoration(
                        labelText: 'المعدة المرتبطة بالصيانة (اختياري)',
                        border: OutlineInputBorder(),
                        helperText:
                            'اختيار المعدة يحول السند إلى سند صيانة معدة',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('- بدون معدة -'),
                        ),
                        ..._equipments.map(
                          (eq) => DropdownMenuItem<int?>(
                            value: eq.id,
                            child: Text(
                              '${eq.name} ${eq.serialNo == null ? '' : '- ${eq.serialNo}'}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: _isOutVoucher
                          ? (v) => setState(() => _equipmentId = v)
                          : null,
                      disabledHint: const Text('متاح فقط في سندات الصرف والإهلاك'),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('كاش')),
                        DropdownMenuItem(value: 'bank', child: Text('تحويل')),
                        DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'cash'),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _ref,
                      decoration: const InputDecoration(
                        labelText: 'رقم مرجعي (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _isDepreciationVoucher
                            ? 'تفاصيل الإهلاك (اختياري)'
                            : (_isMaintenanceVoucher ? 'تفاصيل الصيانة (اختياري)' : 'ملاحظات (اختياري)'),
                        border: const OutlineInputBorder(),
                        helperText: (_isMaintenanceVoucher || _isDepreciationVoucher)
                            ? 'إذا تركته فارغًا سيضيف النظام ملاحظة تلقائية'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        BlocConsumer<PaymentsBloc, PaymentsState>(
          listener: (context, state) {
            if (state.error != null) {
              _submitted = false;
              if (mounted) setState(() => _localSubmitting = false);
            }
            if (_submitted && !state.working && state.error == null) {
              _submitted = false;
              if (mounted) setState(() => _localSubmitting = false);
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            final disabled = state.working || _localSubmitting;
            return ElevatedButton(
              onPressed: disabled
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;

                      final amt = double.tryParse(_amount.text.trim()) ?? 0;
                      final finalNotes = _notes.text.trim().isNotEmpty
                          ? _notes.text.trim()
                          : (_isDepreciationVoucher
                              ? _buildAutoMaintenanceNote()
                              : (_isMaintenanceVoucher
                                  ? _buildAutoMaintenanceNote()
                                  : (_type == 'in' ? 'سند قبض' : 'سند صرف')));

                      setState(() => _localSubmitting = true);
                      _submitted = true;

                      if (editing) {
                        context.read<PaymentsBloc>().add(
                          PaymentUpdated(
                            id: widget.edit!.id,
                            amount: amt,
                            clientId: _clientId,
                            rentId: _rentId,
                            equipmentId: _isOutVoucher ? _equipmentId : null,
                            method: _method,
                            referenceNo: _ref.text.trim().isEmpty
                                ? null
                                : _ref.text.trim(),
                            notes: finalNotes,
                          ),
                        );
                      } else {
                        context.read<PaymentsBloc>().add(
                          PaymentCreated(
                            type: _isDepreciationVoucher ? 'out' : _type,
                            amount: amt,
                            clientId: _clientId,
                            rentId: _rentId,
                            equipmentId: _isOutVoucher ? _equipmentId : null,
                            method: _method,
                            referenceNo: _ref.text.trim().isEmpty
                                ? null
                                : _ref.text.trim(),
                            notes: finalNotes,
                          ),
                        );
                      }
                    },
              child: disabled
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isDepreciationVoucher ? 'حفظ سند الإهلاك' : (_isMaintenanceVoucher ? 'حفظ سند الصيانة' : 'حفظ')), 
            );
          },
        ),
      ],
    );
  }
}
