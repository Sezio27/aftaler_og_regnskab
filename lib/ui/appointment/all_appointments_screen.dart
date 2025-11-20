import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/debug/bench.dart';
import 'package:aftaler_og_regnskab/domain/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/layout_metrics.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/ui/widgets/cards/appointment_card_status.dart';
import 'package:aftaler_og_regnskab/ui/widgets/pickers/date_picker.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/ui/widgets/search_field.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
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

  bool _statusMatches(String? apptStatus) {
    if (_status == PaymentStatus.all) return true;
    return PaymentStatusX.fromString(apptStatus) == _status;
  }

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

    final items = listCards.where((a) {
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
          final itemsCount = items.isNotEmpty ? items.length : 1;
          final loaderCount = listLoading ? 1 : 0;
          return 1 + 1 + itemsCount + loaderCount;
        })(),
        itemBuilder: (context, index) {
          final cs = Theme.of(context).colorScheme;

          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Material(
                    elevation: 1,
                    borderRadius: BorderRadius.all(Radius.circular(10)),

                    child: SearchField(
                      showBorder: false,
                      controller: _searchCtrl,
                      onChanged: (q) => setState(() => _query = q.trim()),
                      ctx: context,
                    ),
                  ),
                  const SizedBox(height: 16),

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
                              _reloadRangeIfValid();
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
                              _reloadRangeIfValid();
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

          final itemIndex = index - 2;

          if (items.isEmpty) {
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
                onChangeStatus: (newStatus) {
                  context.read<AppointmentViewModel>().updateStatus(
                    a.id,
                    newStatus.label,
                  );

                  context.read<FinanceViewModel>().onUpdateStatus(
                    oldStatus: PaymentStatusX.fromString(a.status),
                    newStatus: newStatus,
                    price: a.price ?? 0.0,
                    date: a.time,
                  );
                },
              ),
            );
          }

          final isLoaderRow = (itemIndex == items.length) && listLoading;
          if (isLoaderRow) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

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
        Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
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
