import 'package:aftaler_og_regnskab/screens/calendar_screen.dart';
import 'package:aftaler_og_regnskab/screens/finance_screen.dart';
import 'package:aftaler_og_regnskab/screens/services_screen.dart';
import 'package:aftaler_og_regnskab/screens/settings_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/widgets/app_bottom_nav_bar.dart';
import 'package:aftaler_og_regnskab/widgets/app_top_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: "Godmorgen Jakob",
        subtitle: subtitleDate(),
        action: SizedBox(
          width: 140,
          child: Image.asset(
            'assets/logo_white.png',
            fit: BoxFit.fitWidth,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
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
    final auth = context.watch<FirebaseAuthMethods>();
    final User user = auth.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StatCard(
              title: "Omsætning",
              subtitle: "Denne måned",
              stat: "12.750 kr.",
              height: 180,
              width: 180,
              icon: Icon(
                Icons.attach_money,
                color: AppColors.greenMain,
                size: 28,
              ),
            ),
            if (!user.isAnonymous && user.phoneNumber == null)
              Text(user.email ?? ''),
            if (!user.isAnonymous && user.phoneNumber == null)
              Text(
                user.providerData.isNotEmpty
                    ? user.providerData.first.providerId
                    : '',
              ),
            if (user.phoneNumber != null) Text(user.phoneNumber!),
            Text(user.uid),
            const SizedBox(height: 24),
            CustomButton(
              onTap: () {
                context.read<FirebaseAuthMethods>().signOut(context);
              },
              text: 'Sign Out',
            ),
            const SizedBox(height: 12),
            CustomButton(
              onTap: () {
                context.read<FirebaseAuthMethods>().deleteAccount(context);
              },
              text: 'Delete Account',
            ),
          ],
        ),
      ),
    );
  }
}
