import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:rental_app/features/clients/presentation/ui/ClientsView.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ClientsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (context) =>
            ClientsBloc(context.read<ClientsRepository>())..add(ClientsRequested()),
        child: const ClientsView(),
      ),
    );
  }
}
