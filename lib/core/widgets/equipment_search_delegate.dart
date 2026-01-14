import 'package:flutter/material.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

class EquipmentSearchDelegate extends SearchDelegate<void> {
  EquipmentSearchDelegate(this.items);

  final List<Equipment> items;

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
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final q = query.trim().toLowerCase();

    final filtered = q.isEmpty
        ? items
        : items.where((e) {
            final name = (e.name ?? '').toLowerCase();
            final model = (e.model ?? '').toLowerCase();
            final serial = (e.serialNo ?? '').toLowerCase();
            final status = (e.status ?? '').toLowerCase();

            return name.contains(q) ||
                model.contains(q) ||
                serial.contains(q) ||
                status.contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('لا توجد نتائج'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.construction)),
          title: Text(e.name ?? ''),
          subtitle: Text(
            [e.model, e.serialNo, e.status]
                .where((x) => x != null && x!.isNotEmpty)
                .map((x) => x!)
                .join(' • '),
          ),
          onTap: () => close(context, null), // ✅ الحل هنا
        );
      },
    );
  }
}
