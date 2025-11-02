import 'package:aftaler_og_regnskab/navigation/nav_shell.dart';

import 'package:aftaler_og_regnskab/screens/all_appointments_screen.dart';
import 'package:aftaler_og_regnskab/screens/details/appointment_details_screen.dart';
import 'package:aftaler_og_regnskab/screens/details/checklist_details_screen.dart';
import 'package:aftaler_og_regnskab/screens/details/client_details_screen.dart';
import 'package:aftaler_og_regnskab/screens/clients_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/login_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_location_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_name_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_email_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_name.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_validate_phone_screen.dart';
import 'package:aftaler_og_regnskab/screens/details/service_details_screen.dart';
import 'package:aftaler_og_regnskab/viewModel/calendar_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_gate.dart';
import '../screens/home_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/services_overview_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/new_appointment_screen.dart';

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
  servicesOverview,
  settings,
  newAppointment,
  allAppointments,
  allClients,
  clientDetails,
  serviceDetails,
  checklistDetails,
  appointmentDetails,
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/gate',
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
        redirect: (_, state) {
          final isExactOnboarding = state.uri.path == '/onboarding';
          return isExactOnboarding ? '/login' : null;
        },
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
            routes: [
              GoRoute(
                path: 'validate',
                name: AppRoute.onboardingPhoneValidate.name,
                builder: (_, __) => const ObValidatePhoneScreen(),
              ),
            ],
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
        builder: (context, state, child) {
          return ChangeNotifierProvider(
            create: (_) => CalendarViewModel(),
            child: NavShell(
              location: state.uri.toString(),
              routeName: state.name,
              child: child,
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            name: AppRoute.home.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/calendar',
            name: AppRoute.calendar.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: CalendarScreen()),
          ),
          GoRoute(
            path: '/finance',
            name: AppRoute.finance.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: '/service/overview',
            name: AppRoute.servicesOverview.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: ServicesOverviewScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: AppRoute.settings.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/appointments/new',
            name: AppRoute.newAppointment.name,
            pageBuilder: (_, state) {
              final dateStr = state.uri.queryParameters['date'];
              final initialDate = dateStr != null
                  ? DateTime.tryParse(dateStr)
                  : null;
              return NoTransitionPage(
                child: NewAppointmentScreen(initialDate: initialDate),
              );
            },
          ),
          GoRoute(
            path: '/appointments/all',
            name: AppRoute.allAppointments.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: AllAppointmentsScreen()),
          ),
          GoRoute(
            path: '/clients/all',
            name: AppRoute.allClients.name,
            pageBuilder: (_, state) =>
                const NoTransitionPage(child: ClientsScreen()),
          ),
          GoRoute(
            name: AppRoute.clientDetails.name,
            path: '/clients/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: ClientDetailsScreen(clientId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            name: AppRoute.serviceDetails.name,
            path: '/services/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: ServiceDetailsScreen(
                serviceId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            name: AppRoute.checklistDetails.name,
            path: '/checklists/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: ChecklistDetailsScreen(
                checklistId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            name: AppRoute.appointmentDetails.name,
            path: '/appointments/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: AppointmentDetailsScreen(
                appointmentId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
