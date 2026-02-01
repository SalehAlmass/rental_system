import 'package:flutter/material.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

class ClientSearchDelegate extends SearchDelegate<Client?> {
  ClientSearchDelegate(this.clients);
  final List<Client> clients;

  @override
  String get searchFieldLabel => 'ابحث عن عميل';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [if (query.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(_filtered());

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(_filtered());

  List<Client> _filtered() {
    if (query.isEmpty) return clients;
    final q = query.toLowerCase();
    return clients.where((c) =>
      c.name.toLowerCase().contains(q) ||
      (c.phone ?? '').contains(q) ||
      (c.nationalId ?? '').contains(q)
    ).toList();
  }

  Widget _buildList(List<Client> list) {
    if (list.isEmpty) return const Center(child: Text('لا توجد نتائج'));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final client = list[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(client.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (client.phone != null) Text('📞 ${client.phone}'),
              if (client.nationalId != null) Text('🆔 ${client.nationalId}'),
            ],
          ),
          onTap: () => close(context, client),
        );
      },
    );
  }
}
