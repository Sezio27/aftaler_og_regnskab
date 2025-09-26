// lib/screens/home_screen.dart
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aftaler_og_regnskab/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // no routeName, go_router handles paths

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
         kBottomNavigationBarHeight,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatCard(
                  title: "Omsætning",
                  subtitle: "Denne måned",
                  stat: "12.750 kr.",
                  constraints: const BoxConstraints(
                    minHeight: 190,
                    minWidth: 180,
                  ),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.greenBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      size: 20,
                      color: AppColors.greenMain,
                    ),
                  ),
                ),
                StatCard(
                  title: "Aftaler",
                  subtitle: "Denne måned",
                  stat: "8",
                  constraints: const BoxConstraints(
                    minHeight: 190,
                    minWidth: 180,
                  ),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.peachBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.peach,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            CustomButton(
              text: "Ny aftale",
              icon: const Icon(Icons.add, size: 18, color: Colors.black),
              color: Colors.white,
              width: 170,
              borderRadius: 18,
              textStyle: AppTypography.button2.copyWith(color: Colors.black),
              borderStroke: Border.all(color: AppColors.peach, width: 1),
              onTap: () => context.pushNamed(AppRoute.newAppointment.name),
            ),
            const SizedBox(height: 26),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Kommende aftaler", style: AppTypography.b1),
                  Text("Se alle", style: AppTypography.bold),
                ],
              ),
            ),
            const SizedBox(height: 6),

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
