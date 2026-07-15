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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => context.read<ClientsBloc>().add(ClientsRequested()),
          ),
        ],
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

          return Column(
            children: [
              _buildSortingBar(context, state),
              Expanded(
                child: state.items.isEmpty
                    ? const Center(child: Text('لا يوجد عملاء'))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            context.read<ClientsBloc>().add(ClientsRequested()),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            return ClientCard(client: state.items[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildSortingBar(BuildContext context, ClientsState state) {
    final bloc = context.read<ClientsBloc>();
    final currentSortBy = state.sortBy ?? 'id';
    final currentSortOrder = state.sortOrder ?? 'desc';

    final sortOptions = {
      'id': 'الترتيب الافتراضي',
      'name': 'الاسم',
      'phone': 'رقم الهاتف',
      'national_id': 'الرقم الوطني',
      'created_at': 'تاريخ التسجيل',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
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
                bloc.add(ClientsRequested(sortBy: val));
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
              bloc.add(ClientsRequested(sortOrder: nextOrder));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final bloc = context.read<ClientsBloc>();
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const CreateClientDialog(),
      ),
    );

    if (result == null) return;

    bloc.add(
      ClientCreated(
        name: result["name"],
        phone: result["phone"],
        nationalId: result["nationalId"],
        address: result["address"],
        creditLimit: result["creditLimit"] ?? 0.0,
        isFrozen: result["isFrozen"] ?? 0,
      ),
    );
  }
}
