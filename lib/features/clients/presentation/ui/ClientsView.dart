import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:rental_app/features/clients/presentation/ui/ClientCard.dart';
import 'package:rental_app/features/clients/presentation/ui/ClientDialogs.dart';
import 'package:rental_app/features/clients/presentation/ui/ClientSearchDelegate.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

class ClientsView extends StatelessWidget {
  const ClientsView({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'العملاء',
        onIconPressed: showBackButton ? () {
          Navigator.pop(context);
        } : null,
        icon: (){
          final clients =
              context.read<ClientsBloc>().state.items;
          showSearch<Client?>(
            context: context,
            delegate: ClientSearchDelegate(clients),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'clients_fab', // Unique hero tag to avoid conflicts
        icon: const Icon(Icons.add),
        label: const Text('إضافة عميل'),
        onPressed: () => _openCreateDialog(context),
      ),
      body: PageEntrance(
        child: BlocConsumer<ClientsBloc, ClientsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == ClientsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return const Center(child: Text('لا يوجد عملاء'));
          }

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<ClientsBloc>().add(ClientsRequested()),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                return ClientCard(client: state.items[index]);
              },
            ),
          );
        },
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => const CreateClientDialog(),
    );

    if (result == null) return;

    final bloc = context.read<ClientsBloc>();
    bloc.add(
      ClientCreated(
        name: result["name"],
        phone: result["phone"],
        nationalId: result["nationalId"],
        address: result["address"],
      ),
    );
  }
}
