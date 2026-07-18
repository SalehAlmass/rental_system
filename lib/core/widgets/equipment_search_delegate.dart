import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/utils/debouncer.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/presentation/bloc/equipment_bloc.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/equipment/presentation/ui/EquipmentCard.dart';

class EquipmentSearchDelegate extends SearchDelegate<void> {
  EquipmentSearchDelegate(this.items, this.repo, this.bloc);

  final List<Equipment> items;
  final EquipmentRepository repo;
  final EquipmentBloc bloc;

  @override
  String get searchFieldLabel => 'ابحث عن معدة...';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchWidget(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchWidget(context);

  Widget _buildSearchWidget(BuildContext context) {
    return BlocProvider<EquipmentBloc>.value(
      value: bloc,
      child: _EquipmentSearchSuggestions(
        query: query,
        localItems: items,
        repo: repo,
      ),
    );
  }
}

class _EquipmentSearchSuggestions extends StatefulWidget {
  const _EquipmentSearchSuggestions({
    required this.query,
    required this.localItems,
    required this.repo,
  });

  final String query;
  final List<Equipment> localItems;
  final EquipmentRepository repo;

  @override
  State<_EquipmentSearchSuggestions> createState() => _EquipmentSearchSuggestionsState();
}

class _EquipmentSearchSuggestionsState extends State<_EquipmentSearchSuggestions> {
  List<Equipment> _results = [];
  bool _isLoading = false;
  String? _error;
  final _debouncer = Debouncer(milliseconds: 300);
  String _lastQueried = '';

  @override
  void initState() {
    super.initState();
    _results = widget.localItems;
    _runSearch();
  }

  @override
  void didUpdateWidget(_EquipmentSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _runSearch();
    }
  }

  void _runSearch() {
    _debouncer.cancel();
    final q = widget.query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = widget.localItems;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _debouncer.run(() async {
      _lastQueried = q;
      try {
        final res = await widget.repo.list(query: q);
        if (!mounted || _lastQueried != q) return;
        setState(() {
          _results = res;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted || _lastQueried != q) return;
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    });
  }

  Future<void> _editEquipment(Equipment equipment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<EquipmentBloc>(),
        child: EquipmentDialog(edit: equipment),
      ),
    );
    if (ok == true && mounted) {
      _runSearch();
    }
  }

  @override
  void dispose() {
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'فشل الاتصال بالخادم. تظهر النتائج المحلية فقط.',
            style: TextStyle(color: Colors.orange.shade800),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final e = _results[i];
        return EquipmentCard(
          equipment: e,
          onEdit: _editEquipment,
          onDelete: (eq) {
            context.read<EquipmentBloc>().add(EquipmentDeleted(eq.id));
            _runSearch();
          },
        );
      },
    );
  }
}
