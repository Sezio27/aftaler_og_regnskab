import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/model/clientModel.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:aftaler_og_regnskab/widgets/custom_search_bar.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/images_picker_grid.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_checklist_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_client_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/add_service_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/show_overlay_panel.dart';
import 'package:aftaler_og_regnskab/widgets/overlays/soft_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/pressable_text_overlay.dart';
import 'package:aftaler_og_regnskab/widgets/time_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class NewAppointmentScreen extends StatelessWidget {
  const NewAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Text('Ny aftale', style: AppTypography.h2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const NewAppointmentForm(),
              ),
            ),
          ),

          // Sticky bottom actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Annuller'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // TODO: validate + save
                    },
                    child: const Text('Opret aftale'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewAppointmentForm extends StatefulWidget {
  const NewAppointmentForm({super.key});

  @override
  State<NewAppointmentForm> createState() => _NewAppointmentFormState();
}

class _NewAppointmentFormState extends State<NewAppointmentForm> {
  late final TextEditingController clientSearchCtrl;
  late final TextEditingController serviceSearchCtrl;
  String _clientQuery = '';
  String? _selectedClientId;

  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  int? _active;
  List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    clientSearchCtrl = TextEditingController();
    serviceSearchCtrl = TextEditingController();
    clientSearchCtrl.addListener(() {
      setState(() => _clientQuery = clientSearchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    clientSearchCtrl.dispose();
    serviceSearchCtrl.dispose();
    super.dispose();
  }

  void _clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TapRegion(
      onTapOutside: (_) => _clearFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: 'Vælg klient',
            child: Column(
              children: [
                CustomSearchBar(controller: clientSearchCtrl),
                const SizedBox(height: 8),

                _ClientPickerList(
                  query: _clientQuery,
                  selectedId: _selectedClientId,
                  onPick: (c) {
                    setState(() => _selectedClientId = c.id);
                    // TODO: store c (or id) on the appointment draft if needed
                  },
                ),

                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddClientPanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny klient',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg service',
            child: Column(
              children: [
                CustomSearchBar(controller: serviceSearchCtrl),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddServicePanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny service',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tilknyt checklister',
            child: Column(
              children: [
                CustomSearchBar(controller: serviceSearchCtrl),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    await showOverlayPanel(
                      context: context,
                      child: const AddChecklistPanel(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Tilføj ny checkliste',
                    style: AppTypography.b3.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg tidspunkt',
            child: Row(
              children: [
                Text("Dato:", style: AppTypography.button2),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: DatePicker(
                    value: _date,
                    minimumDate: DateTime(2000),
                    maximumDate: DateTime(2100),
                    onChanged: (d) => setState(() => _date = d),
                  ),
                ),
                const SizedBox(width: 20),
                Text("Tid:", style: AppTypography.button2),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TimePicker(
                    value: _time,
                    onChanged: (t) => setState(() => _time = t),
                    use24h: true,
                    modalHeight: 320,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Vælg lokation',
            child: SoftTextField(
              hintText: "Indtast addresse",
              fill: cs.onPrimary,
              strokeColor: _active != 0
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 0 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 0),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tilpas pris (valgfri)',
            child: SoftTextField(
              hintText:
                  "Standard pris: ", //insert price of service if selected otherwise "indtast pris"
              fill: cs.onPrimary,
              strokeColor: _active != 1
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 1 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 1),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Billeder',
            child: ImagesPickerGrid(
              initial: _images,
              onChanged: (files) => setState(() => _images = files),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Note (valgfri)',
            child: SoftTextField(
              hintText: "Tilføj note til denne aftale",
              maxLines: 3,
              fill: cs.onPrimary,
              strokeColor: _active != 2
                  ? cs.onSurface.withAlpha(50)
                  : cs.primary,
              strokeWidth: _active != 2 ? 1 : 1.5,
              borderRadius: 8,
              showStroke: true,
              onTap: () => setState(() => _active = 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h3),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ClientPickerList extends StatelessWidget {
  const _ClientPickerList({
    required this.query,
    required this.selectedId,
    required this.onPick,
  });

  final String query;
  final String? selectedId;
  final ValueChanged<ClientModel> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stream = context.watch<ClientViewModel>().clientsStream;

    return StreamBuilder<List<ClientModel>>(
      stream: stream,
      builder: (_, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Fejl ved indlæsning',
              style: AppTypography.input2.copyWith(color: cs.error),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        var items = snap.data!;
        if (query.isNotEmpty) {
          bool m(String? v) => (v ?? '').toLowerCase().contains(query);
          items = items
              .where((c) => m(c.name) || m(c.phone) || m(c.email))
              .toList();
        }

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Ingen klienter fundet',
              style: AppTypography.input2.copyWith(
                color: cs.onSurface.withOpacity(.7),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = items[i];
            return _ClientTile(
              c: c,
              selected: c.id == selectedId,
              onTap: () => onPick(c),
            );
          },
        );
      },
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.c, required this.selected, this.onTap});

  final ClientModel c;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.onPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withOpacity(0.12),
            width: selected ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 1),
              color: Colors.black.withOpacity(0.04),
            ),
          ],
        ),
        child: Row(
          children: [
            _Avatar(imageUrl: c.image, name: c.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name ?? '—',
                    style: AppTypography.b2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if ((c.phone ?? '').isNotEmpty)
                        _Info(icon: Icons.phone, text: c.phone!),
                      if ((c.email ?? '').isNotEmpty)
                        _Info(icon: Icons.mail_outline, text: c.email!),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withOpacity(.7)),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.input2.copyWith(
            color: cs.onSurface.withOpacity(.9),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imageUrl, this.name, this.size = 44});
  final String? imageUrl;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget placeholder() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.55,
        color: cs.onSurface.withOpacity(.6),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder();

    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : SizedBox(
                width: size,
                height: size,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      ),
    );
  }
}
