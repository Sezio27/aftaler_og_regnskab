import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/debug/bench.dart';
import 'package:aftaler_og_regnskab/model/appointment_model.dart';
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/widgets/cards/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/widgets/pickers/date_picker.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
      if (pos > 0.8) vm.loadNextListPage();
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
    assert(() {
      bench?.allAppointmentsBuilds++;
      return true;
    }());
    final listCards = context
        .select<AppointmentViewModel, List<AppointmentCardModel>>(
          (v) => v.listCards,
        );
    final listLoading = context.select<AppointmentViewModel, bool>(
      (v) => v.listLoading,
    );
    final listHasMore = context.select<AppointmentViewModel, bool>(
      (v) => v.listHasMore,
    );
    final hPad = LayoutMetrics.horizontalPadding(context);

    // Filter visible items for the list (status/type/query)
    final items = listCards.where((a) {
      return _statusMatches(a.status) &&
          _typeMatches(_type, a) &&
          _queryMatches(_query, a.clientName, a.serviceName);
    }).toList();

    final listbody = Padding(
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
          final itemsCount = items.isNotEmpty
              ? items.length
              : 1; // one row for empty/loading
          final loaderCount = listLoading ? 1 : 0;
          return 1 + 1 + itemsCount + loaderCount;
        })(),
        itemBuilder: (context, index) {
          final cs = Theme.of(context).colorScheme;

          // 0) FILTER CARD (scrolls away)
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Material(
                    elevation: 1,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    child: CupertinoSearchTextField(
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
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
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
                (listCards.isEmpty && !listLoading)
                    ? 'Ingen aftaler i perioden'
                    : 'Resultater: ${items.length}${listHasMore ? " +" : ""}',
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
            if (listLoading) {
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
            final dateText = DateFormat('d/M/yy', 'da').format(a.time);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: AppointmentStatusCard(
                title: a.clientName,
                service: a.serviceName,
                price: a.price,
                dateText: dateText,
                status: a.status,
                onSeeDetails: () {
                  context.pushNamed(
                    AppRoute.appointmentDetails.name,
                    pathParameters: {'id': a.id},
                  );
                },
                onChangeStatus: (newStatus) =>
                    context.read<AppointmentViewModel>().updateStatus(
                      a.id,
                      a.status,
                      a.price,
                      newStatus.label,
                      a.time,
                    ),
              ),
            );
          }

          // 3) FOOTER LOADER (optional, only when more to load)
          final isLoaderRow = (itemIndex == items.length) && listLoading;
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

    return Stack(
      children: [
        listbody,
        if (kDebugMode)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // RESET
                FloatingActionButton.small(
                  heroTag: 'fab-reset',
                  tooltip: 'Reset counters',
                  onPressed: _resetBench,
                  child: const Icon(Icons.restart_alt),
                ),
                const SizedBox(height: 8),
                // SEED
                FloatingActionButton.small(
                  heroTag: 'fab-seed',
                  tooltip: 'Seed demo data',
                  onPressed: _seedDemoData,
                  child: const Icon(Icons.dataset),
                ),
                const SizedBox(height: 8),
                // LOG
                FloatingActionButton.small(
                  heroTag: 'fab-log',
                  tooltip: 'Log BENCH',
                  onPressed: () => bench?.log('AllAppointments snapshot'),
                  child: const Icon(Icons.bug_report),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fab-delete-all',
                  tooltip: 'Slet alle aftaler (DEV)',
                  onPressed: _deleteAllAppointments,
                  child: const Icon(Icons.delete_forever),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
      ],
    );
  }

  void _resetBench() {
    if (bench == null) return;
    bench!
      ..pagedReads = 0
      ..liveFirstReads = 0
      ..liveUpdateReads = 0
      ..allAppointmentsBuilds = 0;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('BENCH counters reset')));
  }

  Future<void> _seedDemoData() async {
    try {
      final repo = context.read<AppointmentRepository>();
      DateTime mStart(DateTime d) => DateTime(d.year, d.month, 1);
      DateTime addMonths(DateTime d, int delta) =>
          DateTime(d.year, d.month + delta, 1);

      final now = DateTime.now();
      final months = [
        mStart(now), // M0 (LIVE)
        mStart(addMonths(now, 1)), // M+1 (LIVE)
        mStart(addMonths(now, 2)), // M+2 (NON-LIVE initially)
        mStart(addMonths(now, 3)), // M+3 (NON-LIVE initially)
      ];

      List<AppointmentModel> monthDocs(DateTime start) {
        // 5 docs per month, safe days inside month
        const days = [3, 10, 17, 24, 27];
        return List.generate(5, (i) {
          final dt = DateTime(
            start.year,
            start.month,
            days[i],
            10 + i,
          ); // 10:00..14:00
          return AppointmentModel(
            dateTime: dt,
            // Only fields needed for our bench
            status: 'uninvoiced',
            checklistIds: const [],
            imageUrls: const [],
          );
        });
      }

      // Commit per-month to minimize snapshot churn (4 commits total)
      for (final m in months) {
        await repo.createAppointmentsBatch(monthDocs(m));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seeded 20 appointments (5 per month x 4)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seed error: $e')));
    }
  }

  Future<void> _deleteAllAppointments() async {
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet alle aftaler?'),
        content: const Text(
          'Dette vil fjerne ALLE aftaler for denne bruger. '
          'Denne handling kan ikke fortrydes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuller'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Slet alt'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = context.read<AppointmentRepository>();
      final vm = context.read<AppointmentViewModel>();

      // Do the nuke
      final deleted = await repo.deleteAllAppointments();

      // Rebuild list state so stale paged data disappears
      // (live months will also clear via listeners)
      vm.beginListRange(_from, _to);

      // Optional: reset your bench counters after a nuke
      bench
        ?..pagedReads = 0
        ..liveFirstReads = 0
        ..liveUpdateReads = 0
        ..allAppointmentsBuilds = 0;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Slettede $deleted aftaler')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fejl ved sletning: $e')));
    }
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
        Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
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
        ),
      ],
    );
  }
}
