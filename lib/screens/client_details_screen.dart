import 'dart:typed_data';
import 'package:aftaler_og_regnskab/model/client_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/persistence_ops.dart';
import 'package:aftaler_og_regnskab/utils/phone_format.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/details/action_buttons.dart';
import 'package:aftaler_og_regnskab/widgets/details/image_pickers.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ClientDetailsScreen extends StatefulWidget {
  const ClientDetailsScreen({super.key, required this.clientId});
  final String clientId;

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  late final ClientViewModel _vm;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ClientViewModel>();
    _vm.subscribeToClient(widget.clientId);
    _subscribed = true;
  }

  @override
  void dispose() {
    if (_subscribed) {
      _vm.unsubscribeFromClient(widget.clientId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ClientViewModel, ClientModel?>(
      selector: (_, vm) => vm.getClient(widget.clientId),
      builder: (context, client, _) {
        if (client == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }

        return _ClientDetailsView(key: ValueKey(client.id), client: client);
      },
    );
  }
}

class _ClientDetailsView extends StatefulWidget {
  const _ClientDetailsView({super.key, required this.client});
  final ClientModel client;

  @override
  State<_ClientDetailsView> createState() => _ClientDetailsViewState();
}

class _ClientDetailsViewState extends State<_ClientDetailsView> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final hPad = LayoutMetrics.horizontalPadding(context);

    return SingleChildScrollView(
      key: const PageStorageKey('clientDetailsScroll'), // keeps scroll offset
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hPad,
          10,
          hPad,
          LayoutMetrics.navBarHeight(context) + 50,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _editing
              ? _ClientEditPane(
                  key: const ValueKey('edit'),
                  client: widget.client,
                  onCancel: () => setState(() => _editing = false),
                  onSaved: () => setState(() => _editing = false),
                )
              : _ClientReadPane(
                  key: const ValueKey('read'),
                  client: widget.client,
                  onEdit: () => setState(() => _editing = true),
                  onDelete: () async {
                    await handleDelete(
                      context: context,
                      componentLabel: 'Klient',
                      onDelete: () => context.read<ClientViewModel>().delete(
                        widget.client.id!,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ClientReadPane extends StatelessWidget {
  const _ClientReadPane({
    super.key,
    required this.client,
    required this.onEdit,
    required this.onDelete,
  });
  final ClientModel client;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                AvatarImagePicker(url: client.image),
                const SizedBox(height: 20),

                Text(client.name ?? "Intet navn", style: AppTypography.h2),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        CustomCard(
          field: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined),
                    const SizedBox(width: 10),
                    Text("Grundlæggende oplysninger", style: AppTypography.b7),
                  ],
                ),
                const SizedBox(height: 10),

                _rowField(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Telefon',
                  read: client.phone?.toGroupedPhone() ?? '---',
                ),

                const SizedBox(height: 6),
                Divider(thickness: 1.2),
                _rowField(
                  context,
                  icon: Icons.mail_outline,
                  label: 'E-mail',
                  read: client.email ?? '---',
                ),

                const SizedBox(height: 6),
                Divider(thickness: 1.2),

                _rowField(
                  context,
                  icon: Icons.map_outlined,
                  label: 'Adresse',
                  read: client.address ?? '---',
                ),

                if (client.postal != null)
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
                if (client.city != null)
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

                if (client.cvr != null) ...[
                  const SizedBox(height: 6),
                  const Divider(thickness: 1.2),
                  _rowField(
                    context,
                    icon: Icons.business_outlined,
                    label: 'CVR',
                    read: client.cvr ?? '---',
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),
        ReadActionsRow(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

class _ClientEditPane extends StatefulWidget {
  const _ClientEditPane({
    super.key,
    required this.client,
    required this.onCancel,
    required this.onSaved,
  });
  final ClientModel client;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<_ClientEditPane> createState() => __ClientEditPaneState();
}

class __ClientEditPaneState extends State<_ClientEditPane> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _postal;
  late final TextEditingController _city;
  late final TextEditingController _cvr;
  int? _active;

  ({Uint8List bytes, String name, String? mimeType})? _newPhoto;
  bool _removeImage = false;

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

  Future<void> _save() async {
    await handleSave(
      context: context,
      validate: () {
        final name = _name.text.trim();
        if (name.isEmpty) return 'Angiv navn på servicen';
        return null;
      },
      onSave: () => context.read<ClientViewModel>().updateClientFields(
        widget.client.id!,
        name: _name.text.trim(),
        phone: _phone.text,
        email: _email.text,
        address: _address.text,
        city: _city.text,
        postal: _postal.text,
        cvr: _cvr.text,
        newImage: _newPhoto,
        removeImage: _removeImage,
      ),
      errorText: () => context.read<ClientViewModel>().error ?? 'Ukendt fejl',
      onSuccess: widget.onSaved, // flip back to read mode
    );
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapRegion(
      onTapInside: (_) => _clearFocus(),
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AvatarImagePicker(
                    url: widget.client.image,
                    newImage: _newPhoto,
                    remove: _removeImage,
                    editable: true,
                    onChanged: (file, remove) {
                      setState(() {
                        _newPhoto = file;
                        _removeImage = remove;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  SoftTextField(
                    hintText: 'Navn',
                    controller: _name,
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    textAlign: TextAlign.center,
                    showStroke: true,
                    strokeColor: _active != 1
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 1 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          CustomCard(
            field: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
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

                  _rowEditField(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'Telefon',
                    child: SoftTextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      fill: cs.onPrimary,
                      borderRadius: 8,
                      showStroke: true,
                      strokeColor: _active != 2
                          ? cs.onSurface.withAlpha(50)
                          : cs.primary,
                      strokeWidth: _active != 2 ? 1 : 1.5,
                      onTap: () => setState(() => _active = 2),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Divider(thickness: 1.2),
                  _rowEditField(
                    context,
                    icon: Icons.mail_outline,
                    label: 'E-mail',

                    child: SoftTextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      fill: cs.onPrimary,
                      borderRadius: 8,
                      showStroke: true,
                      strokeColor: _active != 3
                          ? cs.onSurface.withAlpha(50)
                          : cs.primary,
                      strokeWidth: _active != 3 ? 1 : 1.5,
                      onTap: () => setState(() => _active = 3),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Divider(thickness: 1.2),

                  _rowEditField(
                    context,
                    icon: Icons.map_outlined,
                    label: 'Adresse',

                    child: SoftTextField(
                      controller: _address,
                      keyboardType: TextInputType.streetAddress,
                      fill: cs.onPrimary,
                      borderRadius: 8,
                      showStroke: true,
                      strokeColor: _active != 4
                          ? cs.onSurface.withAlpha(50)
                          : cs.primary,
                      strokeWidth: _active != 4 ? 1 : 1.5,
                      onTap: () => setState(() => _active = 4),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SoftTextField(
                    controller: _postal,
                    keyboardType: TextInputType.number,
                    hintText: 'Postnummer',
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 5
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 5 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 5),
                  ),

                  const SizedBox(height: 8),

                  SoftTextField(
                    controller: _city,
                    hintText: 'By',
                    fill: cs.onPrimary,
                    borderRadius: 8,
                    showStroke: true,
                    strokeColor: _active != 6
                        ? cs.onSurface.withAlpha(50)
                        : cs.primary,
                    strokeWidth: _active != 6 ? 1 : 1.5,
                    onTap: () => setState(() => _active = 6),
                  ),

                  const SizedBox(height: 6),
                  const Divider(thickness: 1.2),
                  _rowEditField(
                    context,
                    icon: Icons.business_outlined,
                    label: 'CVR',

                    child: SoftTextField(
                      controller: _cvr,
                      keyboardType: TextInputType.number,
                      hintText: 'CVR',
                      fill: cs.onPrimary,
                      borderRadius: 8,
                      showStroke: true,
                      strokeColor: _active != 7
                          ? cs.onSurface.withAlpha(50)
                          : cs.primary,
                      strokeWidth: _active != 7 ? 1 : 1.5,
                      onTap: () => setState(() => _active = 7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          Selector<ClientViewModel, bool>(
            selector: (_, vm) => vm.saving,
            builder: (context, saving, _) => EditActionsRow(
              saving: saving,
              onCancel: widget.onCancel,
              onConfirm: _save,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _rowField(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String read,
}) {
  return Column(
    children: [
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(icon, size: 20, color: AppColors.peach),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.b7),
        ],
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(read, style: AppTypography.segPassiveNumber),
        ),
      ),
    ],
  );
}

Widget _rowEditField(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Widget child,
}) {
  return Column(
    children: [
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(icon, size: 20, color: AppColors.peach),
          const SizedBox(width: 10),
          Text(label, style: AppTypography.b7),
        ],
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: child,
        ),
      ),
    ],
  );
}
