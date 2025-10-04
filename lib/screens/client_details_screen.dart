// lib/screens/client_details_screen.dart
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ClientDetailsScreen extends StatelessWidget {
  const ClientDetailsScreen({super.key, required this.clientId, this.client});
  final String clientId;
  final ClientModel? client; // optional, ignored in option B

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Klient')),
      body: StreamBuilder<ClientModel?>(
        stream: context.read<ClientViewModel>().watchClient(clientId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Kunne ikke hente klient',
                style: AppTypography.b4.copyWith(color: cs.error),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data;
          if (c == null) {
            return Center(
              child: Text(
                'Klient ikke fundet',
                style: AppTypography.b4.copyWith(color: cs.onSurface),
              ),
            );
          }

          // Render details
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  c.name ?? '—',
                  style: AppTypography.h3.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 8),
                _kv('Telefon', c.phone),
                _kv('E-mail', c.email),
                _kv('CVR', c.cvr),
                const Divider(height: 24),
                _kv('Adresse', c.address),
                _kv('By', c.city),
                _kv('Postnr.', c.postal),
                // TODO: add actions (edit, delete, create appointment, etc.)
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '—')),
        ],
      ),
    );
  }
}
