// lib/screens/client_details_screen.dart
import 'dart:io';

import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/phone_format.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/image_picker_helper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

class _ClientDetailsView extends StatefulWidget {
  const _ClientDetailsView({required this.client});
  final ClientModel client;

  @override
  State<_ClientDetailsView> createState() => _ClientDetailsViewState();
}

class _ClientDetailsViewState extends State<_ClientDetailsView> {
  bool _editing = false;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _postal;
  late final TextEditingController _city;
  late final TextEditingController _cvr;

  XFile? _newPhoto; // temp picked photo

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.client.name ?? '');
    _phone = TextEditingController(text: widget.client.phone ?? '');
    _email = TextEditingController(text: widget.client.email ?? '');
    _address = TextEditingController(text: widget.client.address ?? '');
    _postal = TextEditingController(text: widget.client.postal ?? '');
    _city = TextEditingController(text: widget.client.city ?? '');
    _cvr = TextEditingController(text: widget.client.cvr ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _postal.dispose();
    _city.dispose();
    _cvr.dispose();
    super.dispose();
  }

  Future<void> _pickNewPhoto() async {
    final picked = await pickImageViaSheet(context);
    if (picked != null && mounted) {
      setState(() => _newPhoto = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<ClientViewModel>();

    var circleAvatar = CircleAvatar(
      radius: 38,
      backgroundColor: cs.secondary.withAlpha(150),
      backgroundImage: _newPhoto != null
          ? FileImage(File(_newPhoto!.path))
          : (widget.client.image != null && widget.client.image!.isNotEmpty)
          ? NetworkImage(widget.client.image!)
          : null,
      child:
          (_newPhoto == null &&
              (widget.client.image == null || widget.client.image!.isEmpty))
          ? const Icon(Icons.person, size: 36)
          : null,
    );

    return Stack(
      children: [
        ListView(
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
                        _editing
                            ? GestureDetector(
                                onTap: _pickNewPhoto,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    circleAvatar,
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : circleAvatar,
                        const SizedBox(height: 14),
                        _editing
                            ? TextField(
                                controller: _name,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'Navn',
                                  border: InputBorder.none,
                                ),
                                style: AppTypography.h2,
                              )
                            : Text(
                                widget.client.name ?? 'Uden navn',
                                style: AppTypography.h2,
                              ),
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

                        _rowField(
                          context,
                          icon: Icons.phone_outlined,
                          label: 'Telefon',
                          read: widget.client.phone?.toGroupedPhone() ?? '---',
                          editChild: TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Telefon',
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Divider(thickness: 1.2),
                        _rowField(
                          context,
                          icon: Icons.mail_outline,
                          label: 'E-mail',
                          read: widget.client.email ?? '---',
                          editChild: TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'E-mail',
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Divider(thickness: 1.2),

                        _rowField(
                          context,
                          icon: Icons.map_outlined,
                          label: 'Adresse',
                          read: widget.client.address ?? '---',
                          editChild: TextField(
                            controller: _address,
                            decoration: const InputDecoration(
                              hintText: 'Adresse',
                            ),
                          ),
                        ),

                        if (!_editing) ...[
                          if (widget.client.postal != null)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  widget.client.postal!,
                                  style: AppTypography.segPassiveNumber,
                                ),
                              ),
                            ),
                          if (widget.client.city != null)
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  widget.client.city!,
                                  style: AppTypography.segPassiveNumber,
                                ),
                              ),
                            ),
                        ] else ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _postal,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Postnummer',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _city,
                            decoration: const InputDecoration(hintText: 'By'),
                          ),
                        ],

                        if (widget.client.cvr != null || _editing) ...[
                          const SizedBox(height: 6),
                          const Divider(thickness: 1.2),
                          _rowField(
                            context,
                            icon: Icons.business_outlined,
                            label: 'CVR',
                            read: widget.client.cvr ?? '---',
                            editChild: TextField(
                              controller: _cvr,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'CVR',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _editing
                      ? Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: "Annuller",
                                onTap: () {
                                  // revert form to current doc values
                                  _name.text = widget.client.name ?? '';
                                  _phone.text = widget.client.phone ?? '';
                                  _email.text = widget.client.email ?? '';
                                  _address.text = widget.client.address ?? '';
                                  _postal.text = widget.client.postal ?? '';
                                  _city.text = widget.client.city ?? '';
                                  _cvr.text = widget.client.cvr ?? '';
                                  setState(() {
                                    _newPhoto = null;
                                    _editing = false;
                                  });
                                },
                                borderRadius: 12,
                                color: cs.onPrimary,
                                textStyle: AppTypography.button3.copyWith(
                                  color: cs.onSurface,
                                ),
                                borderStroke: Border.all(color: cs.onSurface),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: CustomButton(
                                text: vm.saving ? "Gemmer..." : "Bekræft",
                                onTap: vm.saving
                                    ? () {}
                                    : () async {
                                        final ok = await context
                                            .read<ClientViewModel>()
                                            .updateClientFields(
                                              widget.client.id!,
                                              name: _name.text,
                                              phone: _phone.text,
                                              email: _email.text,
                                              address: _address.text,
                                              city: _city.text,
                                              postal: _postal.text,
                                              cvr: _cvr.text,
                                              newImage: _newPhoto,
                                            );
                                        if (!mounted) return;
                                        if (ok) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Opdateret'),
                                            ),
                                          );
                                          setState(() {
                                            _editing = false;
                                            _newPhoto = null;
                                          });
                                        } else {
                                          final err =
                                              context
                                                  .read<ClientViewModel>()
                                                  .error ??
                                              'Ukendt fejl';
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(err)),
                                          );
                                        }
                                      },
                                borderRadius: 12,
                                color: cs.primary,
                                textStyle: AppTypography.button3.copyWith(
                                  color: cs.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: "Rediger",
                                textStyle: AppTypography.button3.copyWith(
                                  color: cs.onSurface,
                                ),
                                onTap: () => setState(() => _editing = true),
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
                                              onPressed: () => ctx.pop(false),
                                              child: const Text('Annuller'),
                                            ),
                                            TextButton(
                                              onPressed: () => ctx.pop(true),
                                              child: const Text('Slet'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (!ok) return;
                                  final vm = context.read<ClientViewModel>();
                                  try {
                                    await vm.delete(
                                      widget.client.id!,
                                      widget.client.image,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Klient slettet'),
                                      ),
                                    );

                                    context.pop();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Kunne ikke slette: $e'),
                                      ),
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
        ),

        if (vm.saving)
          AbsorbPointer(
            absorbing: true,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _rowField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String read,
    required Widget editChild,
  }) {
    final editing = _editing;
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(label, style: AppTypography.b8),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: editing
                ? editChild
                : Text(read, style: AppTypography.segPassiveNumber),
          ),
        ),
      ],
    );
  }
}
