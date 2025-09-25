import 'package:aftaler_og_regnskab/screens/calendar_screen.dart';
import 'package:aftaler_og_regnskab/screens/finance_screen.dart';
import 'package:aftaler_og_regnskab/screens/services_screen.dart';
import 'package:aftaler_og_regnskab/screens/settings_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/app_bottom_nav_bar.dart';
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
import 'package:aftaler_og_regnskab/widgets/appointment_card.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/stat_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _handleItemSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  String subtitleDate() {
    final now = DateTime.now();
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    final weekday = DateFormat('EEEE', 'da').format(now); // e.g. mandag
    final month = DateFormat('MMMM', 'da').format(now); // e.g. december

    return '${cap(weekday)} den ${now.day}. ${cap(month)}';
  }

  PreferredSizeWidget _buildTopBar(int index) {
    switch (index) {
      case 0: // Home
        return AppTopBar(
          title: 'Godmorgen Jakob',
          subtitle: subtitleDate(),
          action: SizedBox(
            width: 140,
            child: Image.asset('assets/logo_white.png', fit: BoxFit.fitWidth),
          ),
        );
      case 1: // Kalender
        return const AppTopBar(title: 'Kalender', subtitle: 'Ugeoversigt');
      case 2: // Regnskab
        return const AppTopBar(title: 'Regnskab');
      case 3: // Services
        return const AppTopBar(
          title: 'Forretning',
          subtitle: 'Administrer services',
        );
      case 4: // Indstillinger
      default:
        return const AppTopBar(title: 'Indstillinger');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(_currentIndex),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeDashboard(),
          CalendarScreen(),
          FinanceScreen(),
          ServicesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onItemSelected: _handleItemSelected,
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          10 + kBottomNavigationBarHeight,
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
                    minHeight: 200,
                    minWidth: 180,
                  ),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.greenBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
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
                    minHeight: 200,
                    minWidth: 180,
                  ),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.peachBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.peach,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: "Ny aftale",
              icon: Icon(Icons.add, size: 20, color: Colors.black),
              color: Colors.white,
              width: 180,
              borderRadius: 20,
              textStyle: AppTypography.button2.copyWith(color: Colors.black),
              borderStroke: Border.all(color: AppColors.peach, width: 1),
              onTap: () {},
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Kommende aftaler", style: AppTypography.b1),
                  Text("Se alle", style: AppTypography.bold),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  AppointmentCard(title: "Sarah Johnson"),
                  const SizedBox(height: 10),
                  AppointmentCard(title: "Emma Nielsen"),
                  const SizedBox(height: 10),
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
