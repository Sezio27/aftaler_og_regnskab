// lib/screens/client_details_screen.dart
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/phone_format.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ClientDetailsScreen extends StatelessWidget {
  const ClientDetailsScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClientViewModel>();

    return StreamBuilder<ClientModel?>(
      stream: vm.watchClient(clientId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Fejl: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final client = snap.data;
        if (client == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _ClientDetailsView(client: client);
      },
    );
  }
}

class _ClientDetailsView extends StatelessWidget {
  const _ClientDetailsView({required this.client});
  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        10,
        20,
        10,
        70 + LayoutMetrics.navBarHeight(context),
      ),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: cs.secondary.withAlpha(150),
                      backgroundImage:
                          (client.image != null && client.image!.isNotEmpty)
                          ? NetworkImage(client.image!)
                          : null,
                      child: (client.image == null || client.image!.isEmpty)
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(client.name ?? 'Uden navn', style: AppTypography.h2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 14,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_outlined),
                        const SizedBox(width: 10),
                        Text(
                          "Grundlæggende oplysninger",
                          style: AppTypography.b7,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Info(
                      title: "Telefon",
                      icon: Icons.phone_outlined,
                      value: client.phone?.toGroupedPhone(),
                    ),
                    const SizedBox(height: 6),
                    Divider(thickness: 1.2),
                    _Info(
                      title: "E-mail",
                      icon: Icons.mail_outline,
                      value: client.email,
                    ),
                    const SizedBox(height: 6),
                    Divider(thickness: 1.2),
                    _Info(
                      title: "Addresse",
                      icon: Icons.map_outlined,
                      value: client.address,
                    ),

                    if (client.postal != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            client.postal!,
                            style: AppTypography.segPassiveNumber,
                          ),
                        ),
                      ),
                    ],
                    if (client.city != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            client.city!,
                            style: AppTypography.segPassiveNumber,
                          ),
                        ),
                      ),
                    ],

                    if (client.cvr != null) ...[
                      const SizedBox(height: 6),
                      Divider(thickness: 1.2),
                      _Info(
                        title: "CVR",
                        icon: Icons.business_outlined,
                        value: client.cvr,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: "Rediger",
                      textStyle: AppTypography.button3.copyWith(
                        color: cs.onSurface,
                      ),
                      onTap: () {},
                      borderRadius: 12,
                      icon: Icon(Icons.edit_outlined),
                      color: cs.onPrimary,
                      borderStroke: Border.all(color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: CustomButton(
                      text: "Slet",
                      textStyle: AppTypography.button3.copyWith(
                        color: cs.error,
                      ),
                      onTap: () async {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Slet klient?'),
                                content: const Text(
                                  'Dette kan ikke fortrydes.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annuller'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Slet'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (!ok) return;
                        final vm = context.read<ClientViewModel>();
                        try {
                          await vm.delete(client.id!, client.image);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Klient slettet')),
                          );

                          context.pop();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kunne ikke slette: $e')),
                          );
                        }
                      },
                      borderRadius: 12,
                      icon: Icon(Icons.delete, color: cs.error),
                      color: cs.onPrimary,
                      borderStroke: Border.all(color: cs.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.title, this.value});
  final IconData icon;
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(title, style: AppTypography.b8),
          ],
        ),

        const SizedBox(height: 12),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(value ?? "---", style: AppTypography.segPassiveNumber),
          ),
        ),
      ],
    );
  }
}
