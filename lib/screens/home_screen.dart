// lib/screens/home_screen.dart
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/status_color.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/widgets/avatar.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // go_router handles paths

  // Build one merged list of cards for [start..end] by reusing cardsForDate.
  Future<List<AppointmentCardModel>> _cardsForRange(
    AppointmentViewModel vm,
    DateTime start,
    DateTime end,
  ) async {
    final List<AppointmentCardModel> out = [];
    for (
      var d = DateTime(start.year, start.month, start.day);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      final dayCards = await vm.cardsForDate(d);
      out.addAll(dayCards);
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final apptVm = context.watch<AppointmentViewModel>();

    final now = DateTime.now();

    // Month range for stats
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    // 2-week range for the list (unchanged)
    final listStart = DateTime(now.year, now.month, now.day);
    final listEnd = listStart.add(const Duration(days: 14));

    // Load a superset: the whole month (covers both stats + list)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      apptVm.setActiveRange(monthStart, monthEnd);
    });

    // Use your new helpers
    final monthlyCount = apptVm.countAppointmentsInRange(monthStart, monthEnd);
    final monthlyPaid = apptVm.sumPaidInRangeDKK(monthStart, monthEnd);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        child: Column(
          children: [
            Row(
              children: [
                StatCard(
                  title: "Omsætning",
                  subtitle: "Denne måned",
                  value: '${monthlyPaid.toStringAsFixed(0)} Kr.',
                  icon: Icon(
                    Icons.account_balance_outlined,
                    size: 20,
                    color: AppColors.greenMain,
                  ),
                  valueColor: AppColors.greenMain,
                  iconBgColor: AppColors.greenBackground,
                ),
                const SizedBox(width: 16),
                StatCard(
                  title: "Aftaler",
                  subtitle: "Denne måned",
                  value: monthlyCount.toString(),
                  icon: Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: AppColors.peach,
                  ),
                  valueColor: cs.onSurface,
                  iconBgColor: AppColors.peachBackground,
                ),
              ],
            ),
            const SizedBox(height: 26),

            CustomButton(
              text: "Ny aftale",
              icon: Icon(Icons.add, size: 18, color: cs.onSurface),
              color: Colors.white,
              width: 170,
              borderRadius: 18,
              textStyle: AppTypography.button2.copyWith(color: cs.onSurface),
              borderStroke: Border.all(color: cs.secondary, width: 1),
              onTap: () => context.pushNamed(AppRoute.newAppointment.name),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Kommende aftaler",
                    style: AppTypography.b1.copyWith(color: cs.onSurface),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.pushNamed(AppRoute.allAppointments.name),
                    child: Text(
                      'Se alle',
                      style: AppTypography.b3.copyWith(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Reuse existing VM methods to build a 2-week forward agenda
            FutureBuilder<List<AppointmentCardModel>>(
              future: _cardsForRange(apptVm, listStart, listEnd),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Ingen kommende aftaler",
                        style: AppTypography.b3.copyWith(
                          color: cs.onSurface.withAlpha(150),
                        ),
                      ),
                    ),
                  );
                }

                // Inside SingleChildScrollView → use a non-scrolling, shrink-wrapped list
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = items[i];
                    final dateText = DateFormat('d/M', 'da').format(a.time);
                    final timeText = MaterialLocalizations.of(context)
                        .formatTimeOfDay(
                          TimeOfDay.fromDateTime(a.time),
                          alwaysUse24HourFormat: true,
                        );

                    return AppointmentCard(
                      avatar: Avatar(imageUrl: a.imageUrl),
                      title: a.clientName,
                      subtitle: a.serviceName,
                      price: a.price,
                      date: dateText,
                      time: timeText,
                      color: statusColor(a.status),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconBgColor,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color valueColor;
  final Widget icon;
  final Color iconBgColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        constraints: const BoxConstraints(minHeight: 180),
        field: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.b2,
              ),
              Text(
                value,
                textAlign: TextAlign.center,
                style: AppTypography.numStat.copyWith(color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
