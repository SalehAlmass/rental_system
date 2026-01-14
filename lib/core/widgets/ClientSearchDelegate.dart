import 'package:flutter/material.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

class ClientSearchDelegate extends SearchDelegate<Client?> {
  ClientSearchDelegate(this.items);

  final List<Client> items;

  @override
  String get searchFieldLabel => 'ابحث عن عميل...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? items
        : items.where((c) {
            final name = c.name.toLowerCase();
            final phone = (c.phone ?? '').toLowerCase();
            final nid = (c.nationalId ?? '').toLowerCase();
            return name.contains(q) || phone.contains(q) || nid.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(c.name),
          subtitle: Text(
            [c.phone, c.nationalId]
                .where((e) => e != null && e!.isNotEmpty)
                .map((e) => e!)
                .join(' • '),
          ),
          onTap: () => close(context, c),
        );
      },
    );
  }
}
