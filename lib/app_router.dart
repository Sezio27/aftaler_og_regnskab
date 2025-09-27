// lib/app_router.dart
import 'package:aftaler_og_regnskab/app_layout.dart';
import 'package:aftaler_og_regnskab/navigation/nav_shell.dart';
import 'package:aftaler_og_regnskab/navigation/tab_config.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/login_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_location_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_name_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_email_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_name.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_validate_phone_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_gate.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/services_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/new_appointment_screen.dart';

enum AppRoute {
  gate,
  login,
  onboarding,
  onboardingEmail,
  onboardingPhone,
  onboardingPhoneValidate,
  onboardingName,
  onboardingBusinessName,
  onboardingBusinessLocation,
  home,
  calendar,
  finance,
  services,
  settings,
  newAppointment,
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/gate',
        name: AppRoute.gate.name,
        builder: (_, __) => const AuthGate(),
      ),
      GoRoute(
        path: '/login',
        name: AppRoute.login.name,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: AppRoute.onboarding.name,
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: 'email',
            name: AppRoute.onboardingEmail.name,
            builder: (_, __) => const ObEmailScreen(),
          ),
          GoRoute(
            path: 'phone',
            name: AppRoute.onboardingPhone.name,
            builder: (_, __) => const ObEnterPhoneScreen(),
          ),
          GoRoute(
            path: 'phone/validate',
            name: AppRoute.onboardingPhoneValidate.name,
            builder: (_, __) => const ObValidatePhoneScreen(),
          ),
          GoRoute(
            path: 'name',
            name: AppRoute.onboardingName.name,
            builder: (_, __) => const ObNameScreen(),
          ),
          GoRoute(
            path: 'business-name',
            name: AppRoute.onboardingBusinessName.name,
            builder: (_, __) => const ObBusinessNameScreen(),
          ),
          GoRoute(
            path: 'business-location',
            name: AppRoute.onboardingBusinessLocation.name,
            builder: (_, __) => const ObBusinessLocationScreen(),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) =>
            NavShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: AppRoute.home.name,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: AppRoute.calendar.name,
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/finance',
            name: AppRoute.finance.name,
            builder: (_, __) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/services',
            name: AppRoute.services.name,
            builder: (_, __) => const ServicesScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: AppRoute.settings.name,
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/appointments/new',
            name: AppRoute.newAppointment.name,
            builder: (_, __) => const NewAppointmentScreen(),
          ),
        ],
      ),
    ],
  );
}
