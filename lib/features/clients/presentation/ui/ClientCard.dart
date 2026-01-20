import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:rental_app/features/clients/presentation/ui/ClientDialogs.dart';
import 'package:rental_app/features/clients/presentation/ui/client_details_page.dart';

class ClientCard extends StatelessWidget {
  const ClientCard({required this.client, super.key});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ClientsBloc>();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          // Navigate to client details page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClientDetailsPage(client: client),
            ),
          );
        },
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (client.phone?.isNotEmpty ?? false) Text('📞 ${client.phone}'),
              if (client.nationalId?.isNotEmpty ?? false) Text('🆔 ${client.nationalId}'),
              Text('الحد الائتماني: ${client.creditLimit.toStringAsFixed(0)}'),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () async {
                final updated = await showDialog<bool>(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: EditClientDialog(client: client),
                  ),
                );
                if (updated == true && context.mounted) {
                  bloc.add(ClientsRequested());
                }
              },
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: Text('هل أنت متأكد من حذف العميل "${client.name}"؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  bloc.add(ClientDeleted(id: client.id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
