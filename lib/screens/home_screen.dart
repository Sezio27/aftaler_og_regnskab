// lib/screens/home_screen.dart
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // no routeName, go_router handles paths

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        child: Column(
          children: [
            Row(
              children: [
                StatCard(
                  title: "Omsætning",
                  subtitle: "Denne måned",
                  value: "12.750 Kr.",
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
                  value: "8",
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

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  SizedBox(height: 6),
                  AppointmentCard(title: "Sarah Johnson"),
                  SizedBox(height: 6),
                  AppointmentCard(title: "Emma Nielsen"),
                  SizedBox(height: 6),
                  AppointmentCard(title: "Lisa Wang"),
                ],
              ),
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
