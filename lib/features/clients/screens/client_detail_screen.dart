import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/providers/providers.dart';
import 'add_edit_client_screen.dart';

class ClientDetailScreen extends ConsumerWidget {
  final int clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final client = await _getClient(database);
              if (client != null && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditClientScreen(client: client),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Client?>(
        future: _getClient(database),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Client not found'));
          }

          final client = snapshot.data!;
          final isActive = client.isActive &&
              (client.expiryDate != null &&
                  client.expiryDate!.isAfter(DateTime.now()));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              isActive ? Colors.green : Colors.grey,
                          child: Text(
                            client.name[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 32, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          client.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(client.phone),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(isActive ? 'Active' : 'Inactive'),
                          backgroundColor: isActive ? Colors.green : Colors.red,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (client.address != null)
                  Card(
                    child: ListTile(
                      title: const Text('Address'),
                      subtitle: Text(client.address!),
                      leading: const Icon(Icons.location_on),
                    ),
                  ),
                if (client.email != null)
                  Card(
                    child: ListTile(
                      title: const Text('Email'),
                      subtitle: Text(client.email!),
                      leading: const Icon(Icons.email),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Client?> _getClient(SupabaseDataService database) async {
    return await database.getClientById(clientId);
  }
}
