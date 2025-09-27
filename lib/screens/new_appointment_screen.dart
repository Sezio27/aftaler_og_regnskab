import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';

class NewAppointmentScreen extends StatelessWidget {
  const NewAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Lightweight top row (since there’s no AppBar)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'Ny aftale',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const _NewAppointmentForm(),
            ),
          ),
        ),

        // Sticky bottom actions
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.06)),
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
    );
  }
}

class _NewAppointmentForm extends StatelessWidget {
  const _NewAppointmentForm();

  @override
  Widget build(BuildContext context) {
    // TODO: Wire up controllers + state management later.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Kunde',
          child: _CardWrap(
            child: Column(
              children: const [
                _FieldPlaceholder(label: 'Vælg eksisterende kunde / Opret ny'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Service',
          child: _CardWrap(
            child: Column(
              children: const [
                _FieldPlaceholder(label: 'Vælg service(r)'),
                _FieldPlaceholder(label: 'Noter (valgfrit)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Tid & Sted',
          child: _CardWrap(
            child: Column(
              children: const [
                _FieldPlaceholder(label: 'Dato'),
                _FieldPlaceholder(label: 'Starttid'),
                _FieldPlaceholder(label: 'Varighed'),
                _FieldPlaceholder(label: 'Adresse / On-site'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Betaling',
          child: _CardWrap(
            child: Column(
              children: const [
                _FieldPlaceholder(label: 'Pris'),
                _FieldPlaceholder(label: 'Depositum'),
                _FieldPlaceholder(label: 'Faktura / MobilePay'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Extra long content placeholder to ensure scrolling works well
        const _FieldPlaceholder(
          label: '— ekstra plads til fremtidige felter —',
          minHeight: 120,
        ),
      ],
    );
  }
}

// ——— UI helpers (simple skeleton styling) ———

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.b1),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _CardWrap extends StatelessWidget {
  const _CardWrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs
            .surfaceContainerHighest, // or AppColors.peachBackground if you prefer
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _FieldPlaceholder extends StatelessWidget {
  const _FieldPlaceholder({required this.label, this.minHeight = 52});
  final String label;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: minHeight,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: AppTypography.num1, //.copyWith(color: AppColors.textLight),
      ),
    );
  }
}
