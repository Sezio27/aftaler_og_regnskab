import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/widgets/avatar.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:aftaler_og_regnskab/widgets/date_picker.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum ApptType { all, private, business }

class AllAppointmentsScreen extends StatefulWidget {
  const AllAppointmentsScreen({super.key});

  @override
  State<AllAppointmentsScreen> createState() => _AllAppointmentsScreenState();
}

class _AllAppointmentsScreenState extends State<AllAppointmentsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _query = '';
  ApptType _type = ApptType.all;
  PaymentStatus _status = PaymentStatus.all;
  DateTime _from = startOfMonth(DateTime.now());
  DateTime _to = endOfMonthInclusive(DateTime.now());

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final vm = context.read<AppointmentViewModel>();
      if (!vm.listHasMore || vm.listLoading) return;
      if (_scrollCtrl.position.maxScrollExtent <= 0) return;
      final pos =
          _scrollCtrl.position.pixels / _scrollCtrl.position.maxScrollExtent;
      if (pos > 0.8) vm.loadNextListMonth();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadRangeIfValid());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _typeText(ApptType t) => switch (t) {
    ApptType.all => 'Alle',
    ApptType.private => 'Privat',
    ApptType.business => 'Erhverv',
  };

  String _dateText(DateTime? d) => d == null
      ? 'dd/mm/år'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // --- Simple client-side filters (cheap, easy to understand) ---
  bool _statusMatches(String? apptStatus) {
    if (_status == PaymentStatus.all) return true;
    return PaymentStatusX.fromString(apptStatus) == _status;
  }

  // NOTE: You didn’t share how “type” is stored. For now we keep all.
  bool _typeMatches(ApptType sel, AppointmentCardModel a) {
    if (sel == ApptType.all) return true;
    return sel == ApptType.business ? a.isBusiness : !a.isBusiness;
  }

  bool _queryMatches(String q, String clientName, String serviceName) {
    if (q.isEmpty) return true;
    final x = q.toLowerCase();
    return clientName.toLowerCase().contains(x) ||
        serviceName.toLowerCase().contains(x);
  }

  void _reloadRangeIfValid() {
    if (!_to.isBefore(_from)) {
      // optional: scroll to top so the user sees new results
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      context.read<AppointmentViewModel>().beginListRange(_from, _to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<AppointmentViewModel>();
    final hPad = LayoutMetrics.horizontalPadding(context);

    // Filter visible items for the list (status/type/query)
    final items = vm.listCards.where((a) {
      return _statusMatches(a.status) &&
          _typeMatches(_type, a) &&
          _queryMatches(_query, a.clientName, a.serviceName);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hPad / 2,
        6,
        hPad / 2,
        LayoutMetrics.navBarHeight(context),
      ),
      child: ListView.builder(
        controller: _scrollCtrl,

        itemCount: (() {
          // 1 filter card + 1 results header +  (items or a single "state" row) + optional loader
          final vm = context.read<AppointmentViewModel>();
          final itemsCount = items.isNotEmpty
              ? items.length
              : 1; // one row for empty/loading
          final loaderCount = vm.listHasMore ? 1 : 0;
          return 1 + 1 + itemsCount + loaderCount;
        })(),
        itemBuilder: (context, index) {
          final cs = Theme.of(context).colorScheme;
          final vm = context.read<AppointmentViewModel>();

          // 0) FILTER CARD (scrolls away)
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  CupertinoSearchTextField(
                    controller: _searchCtrl,
                    placeholder: 'Søg',
                    onChanged: (q) => setState(() => _query = q.trim()),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    itemColor: cs.onSurface.withAlpha(180),
                    style: AppTypography.b2.copyWith(color: cs.onSurface),
                    placeholderStyle: AppTypography.b2.copyWith(
                      color: cs.onSurface.withAlpha(180),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.onPrimary,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filters row 1
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
                          valueText: _status.label,
                          onTap: _pickStatus,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filters row 2
                  Row(
                    children: [
                      Expanded(
                        child: _FilterField(
                          label: 'Fra',
                          valueText: _dateText(_from),
                          style: AppTypography.num8.copyWith(
                            color: cs.onSurface.withAlpha(180),
                          ),
                          onTap: () async {
                            final picked = await context.pickCupertinoDate(
                              initial: _from,
                              maximumDate: _to,
                            );
                            if (picked != null) {
                              setState(() => _from = picked);
                              _reloadRangeIfValid(); // <— auto fetch
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _FilterField(
                          label: 'Til',
                          style: AppTypography.num8.copyWith(
                            color: cs.onSurface.withAlpha(180),
                          ),
                          valueText: _dateText(_to),
                          onTap: () async {
                            final picked = await context.pickCupertinoDate(
                              initial: _to,
                              minimumDate: _from,
                            );
                            if (picked != null) {
                              setState(() => _to = picked);
                              _reloadRangeIfValid(); // <— auto fetch
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }

          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
              child: Text(
                (vm.listCards.isEmpty && !vm.listLoading)
                    ? 'Ingen aftaler i perioden'
                    : 'Resultater: ${items.length}${vm.listHasMore ? " +" : ""}',
                style: AppTypography.b3.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            );
          }

          // Adjust index for items section
          final itemIndex = index - 2;

          // 2) LIST CONTENT (empty/loading state or real items)
          if (items.isEmpty) {
            // Single row representing empty/loading state
            if (vm.listLoading) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Ingen aftaler matcher dine filtre.',
                  style: AppTypography.b4.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            );
          }

          // When we have items:
          if (itemIndex < items.length) {
            final a = items[itemIndex];
            final dateText = DateFormat('d/M', 'da').format(a.time);
            final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(a.time),
              alwaysUse24HourFormat: true,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: AppointmentCard(
                avatar: Avatar(imageUrl: a.imageUrl),
                title: a.clientName,
                subtitle: a.serviceName,
                price: a.price,
                date: dateText,
                time: timeText,
                color: statusColor(a.status),
                onTap: () {
                  context.pushNamed(
                    AppRoute.appointmentDetails.name,
                    pathParameters: {'id': a.id},
                  );
                },
              ),
            );
          }

          // 3) FOOTER LOADER (optional, only when more to load)
          final isLoaderRow = (itemIndex == items.length) && vm.listHasMore;
          if (isLoaderRow) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // Fallback: nothing
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _pickType() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Vælg type'),
        actions: ApptType.values.map((t) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _type = t);
              context.pop();
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
        actions: PaymentStatus.values.map((s) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _status = s);
              context.pop();
            },
            isDefaultAction: s == _status,
            child: Text(s.label),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuller'),
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
    this.style,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.b2),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.onPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueText,
                    style:
                        style ??
                        AppTypography.b2.copyWith(
                          color: cs.onSurface.withAlpha(180),
                        ),
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
