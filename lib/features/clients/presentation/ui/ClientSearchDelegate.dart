import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rental_app/core/utils/debouncer.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';

class ClientSearchDelegate extends SearchDelegate<Client?> {
  ClientSearchDelegate(this.clients, this.repo);
  final List<Client> clients;
  final ClientsRepository repo;

  @override
  String get searchFieldLabel => 'ابحث عن عميل';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchWidget(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchWidget(context);
  }

  Widget _buildSearchWidget(BuildContext context) {
    return _ClientSearchSuggestions(
      query: query,
      localClients: clients,
      repo: repo,
      onTap: (client) => close(context, client),
    );
  }
}

class _ClientSearchSuggestions extends StatefulWidget {
  const _ClientSearchSuggestions({
    required this.query,
    required this.localClients,
    required this.repo,
    required this.onTap,
  });

  final String query;
  final List<Client> localClients;
  final ClientsRepository repo;
  final Function(Client) onTap;

  @override
  State<_ClientSearchSuggestions> createState() => _ClientSearchSuggestionsState();
}

class _ClientSearchSuggestionsState extends State<_ClientSearchSuggestions> {
  List<Client> _results = [];
  bool _isLoading = false;
  String? _error;
  final _debouncer = Debouncer(milliseconds: 300);
  String _lastQueried = '';

  @override
  void initState() {
    super.initState();
    _results = widget.localClients;
    _runSearch();
  }

  @override
  void didUpdateWidget(_ClientSearchSuggestions oldWidget) {
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
        _results = widget.localClients;
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
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final client = _results[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(client.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (client.phone != null && client.phone!.isNotEmpty) Text('📞 ${client.phone}'),
              if (client.nationalId != null && client.nationalId!.isNotEmpty) Text('🆔 ${client.nationalId}'),
            ],
          ),
          onTap: () => widget.onTap(client),
        );
      },
    );
  }
}
