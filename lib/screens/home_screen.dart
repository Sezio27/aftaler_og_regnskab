// lib/screens/home_screen.dart
import 'package:aftaler_og_regnskab/model/appointment_card_model.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/utils/paymentStatus.dart';
import 'package:aftaler_og_regnskab/utils/range.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/widgets/avatar.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppointmentViewModel>().ensureFinanceForHomeSeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();

    final twoWeek = twoWeekRange(now);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        child: Column(
          children: [
            Selector<AppointmentViewModel, ({double income, int count})>(
              selector: (_, vm) => vm.summaryNow(Segment.month),
              builder: (_, summary, __) {
                return Row(
                  children: [
                    StatCard(
                      title: "Omsætning",
                      subtitle: "Denne måned",
                      value: formatDKK(summary.income),
                      icon: const Icon(
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
                      value: summary.count.toString(),
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: AppColors.peach,
                      ),
                      valueColor: cs.onSurface,
                      iconBgColor: AppColors.peachBackground,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 26),

            CustomButton(
              text: "Ny aftale",
              icon: Icon(Icons.add, size: 18, color: cs.onSurface),
              color: cs.surface,
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

            // Upcoming list fed from VM memory
            Selector<
              AppointmentViewModel,
              ({bool ready, List<AppointmentCardModel> items})
            >(
              selector: (_, vm) => (
                ready: vm.isReady,
                items: vm.cardsForRange(twoWeek.start, twoWeek.end),
              ),
              // keep it simple: let it rebuild whenever the tuple changes
              builder: (context, data, _) {
                if (!data.ready) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final items = data.items;
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
                      key: ValueKey('appt-${a.id}'),
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
