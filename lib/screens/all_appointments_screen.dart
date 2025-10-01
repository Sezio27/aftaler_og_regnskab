import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ApptType { all, private, business }

enum ApptStatus { all, paid, waiting, expired, uninvoiced }

class AllAppointmentsScreen extends StatefulWidget {
  const AllAppointmentsScreen({super.key});

  @override
  State<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends State<AllAppointmentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  ApptType _type = ApptType.all;
  ApptStatus _status = ApptStatus.all;
  DateTime? _from;
  DateTime? _to;

  String _typeText(ApptType t) => switch (t) {
    ApptType.all => 'Alle',
    ApptType.private => 'Privat',
    ApptType.business => 'Erhverv',
  };

  String _statusText(ApptStatus s) => switch (s) {
    ApptStatus.all => 'Alle',
    ApptStatus.paid => 'Betalt',
    ApptStatus.waiting => 'Afventer',
    ApptStatus.expired => 'Forfalden',
    ApptStatus.uninvoiced => 'Ufaktureret',
  };
  Future<void> _pickType() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Vælg type'),
        actions: ApptType.values.map((t) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _type = t);
              Navigator.pop(context);
            },
            isDefaultAction: t == _type,
            child: Text(_typeText(t)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuller'),
        ),
      ),
    );
  }

  Future<void> _pickStatus() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Vælg status'),
        actions: ApptStatus.values.map((s) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _status = s);
              Navigator.pop(context);
            },
            isDefaultAction: s == _status,
            child: Text(_statusText(s)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuller'),
        ),
      ),
    );
  }

  String _dateText(DateTime? d) => d == null
      ? 'dd/mm/år'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    CupertinoSearchTextField(
                      controller: _searchCtrl,
                      placeholder: 'Søg',
                      onChanged: (q) => setState(() => _query = q.trim()),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      itemColor: cs.onSurface.withAlpha(150),
                      style: AppTypography.b2.copyWith(color: cs.onSurface),
                      placeholderStyle: AppTypography.b2.copyWith(
                        color: cs.onSurface.withAlpha(150),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        boxShadow: [
                          BoxShadow(
                            color: cs.onSurface.withAlpha(150),
                            offset: Offset(0, 1),
                            blurRadius: 0.5,
                            blurStyle: BlurStyle.outer,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Two-column grid of filters
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            label: 'Type',
                            valueText: _typeText(_type),
                            onTap: _pickType,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _FilterField(
                            label: 'Status',
                            valueText: _statusText(_status),
                            onTap: _pickStatus,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            label: 'Fra',
                            valueText: _dateText(_from),
                            onTap: () async {
                              final picked = await context.pickCupertinoDate(
                                initial: _from ?? DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _from = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _FilterField(
                            label: 'Til',
                            valueText: _dateText(_to),
                            onTap: () async {
                              final picked = await context.pickCupertinoDate(
                                initial: _to ?? DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _to = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.b2.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface, // your beige
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueText,
                    style: AppTypography.b2.copyWith(color: cs.onSurface),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_down, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
