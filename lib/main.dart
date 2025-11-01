// main.dart
import 'dart:async';
import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/application/appointment_notifications.dart';
import 'package:aftaler_og_regnskab/data/cache/appointment_cache.dart';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/cache/checklist_cache.dart';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/data/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/data/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/data/finance_summary_repository.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/data/user_repository.dart';
import 'package:aftaler_og_regnskab/debug/bench.dart';
import 'package:aftaler_og_regnskab/firebase_options.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/services/notification_service.dart';
import 'package:aftaler_og_regnskab/theme/app_theme.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/finance_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/user_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('da');
  final appRouter = createRouter();
  assert(() {
    bench = Bench();
    return true;
  }());
  runApp(MyApp(router: appRouter));
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance),
        Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
        ProxyProvider<FirebaseAuth, FirebaseAuthMethods>(
          update: (_, auth, __) => FirebaseAuthMethods(auth),
        ),
        ProxyProvider2<FirebaseAuth, FirebaseFirestore, UserRepository>(
          update: (_, auth, db, __) =>
              UserRepository(auth: auth, firestore: db),
        ),
        ProxyProvider2<FirebaseAuth, FirebaseFirestore, ClientRepository>(
          update: (_, auth, db, __) =>
              ClientRepository(auth: auth, firestore: db),
        ),
        ProxyProvider2<FirebaseAuth, FirebaseFirestore, ServiceRepository>(
          update: (_, auth, db, __) =>
              ServiceRepository(auth: auth, firestore: db),
        ),
        ProxyProvider2<FirebaseAuth, FirebaseFirestore, ChecklistRepository>(
          update: (_, auth, db, __) =>
              ChecklistRepository(auth: auth, firestore: db),
        ),
        ProxyProvider2<FirebaseAuth, FirebaseFirestore, AppointmentRepository>(
          update: (_, auth, db, __) =>
              AppointmentRepository(auth: auth, firestore: db),
        ),
        Provider(create: (_) => ImageStorage()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider(
          create: (ctx) =>
              AppointmentNotifications(ctx.read<NotificationService>()),
        ),
        Provider<ClientCache>(
          create: (ctx) => ClientCache(ctx.read<ClientRepository>()),
        ),
        Provider<ServiceCache>(
          create: (ctx) => ServiceCache(ctx.read<ServiceRepository>()),
        ),
        Provider<ChecklistCache>(
          create: (ctx) => ChecklistCache(ctx.read<ChecklistRepository>()),
        ),
        Provider<AppointmentCache>(
          create: (ctx) => AppointmentCache(ctx.read<AppointmentRepository>()),
        ),
        Provider<FinanceSummaryRepository>(
          create: (ctx) => FinanceSummaryRepository(
            auth: ctx.read<FirebaseAuth>(),
            firestore: ctx.read<FirebaseFirestore>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (ctx) => ClientViewModel(
            ctx.read<ClientRepository>(),
            ctx.read<ImageStorage>(),
            ctx.read<ClientCache>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ServiceViewModel(
            ctx.read<ServiceRepository>(),
            ctx.read<ImageStorage>(),
            ctx.read<ServiceCache>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChecklistViewModel(
            ctx.read<ChecklistRepository>(),
            ctx.read<ChecklistCache>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              FinanceViewModel(ctx.read<FinanceSummaryRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            return AppointmentViewModel(
              ctx.read<AppointmentRepository>(),
              ctx.read<ImageStorage>(),
              clientCache: ctx.read<ClientCache>(),
              serviceCache: ctx.read<ServiceCache>(),
              checklistCache: ctx.read<ChecklistCache>(),
              apptCache: ctx.read<AppointmentCache>(),
              financeVM: ctx.read<FinanceViewModel>(),
              notifications: ctx.read<AppointmentNotifications>(),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) => OnboardingViewModel(ctx.read<UserRepository>()),
        ),

        ChangeNotifierProvider(
          create: (ctx) => UserViewModel(ctx.read<UserRepository>()),
        ),
      ],
      child: _AppBootstrap(router: router),
    );
  }
}

/// Sets the initial active range to the current year after auth.
/// Leaves screens free of setActiveRange calls.
class _AppBootstrap extends StatefulWidget {
  final GoRouter router;
  const _AppBootstrap({required this.router});

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

// _AppBootstrapState (replace your initState with this version)

class _AppBootstrapState extends State<_AppBootstrap> {
  StreamSubscription<User?>? _authSub;
  bool _didBootstrap = false;
  Future<void>? _prefsInit;

  Future<void> _onSignedIn() async {
    if (_didBootstrap) {
      context.read<AppointmentViewModel>().setInitialRange();
      return;
    }

    final ns = context.read<NotificationService>();
    final userVM = context.read<UserViewModel>();
    final apptVM = context.read<AppointmentViewModel>();

    //Notifications
    await ns.init();
    _prefsInit = userVM.loadLocalPreferences(ns);
    await userVM.initNotificationsIfFirstRun(ns);
    await _prefsInit;

    await ns.applyEnabled(userVM.notificationsOn);

    apptVM.setInitialRange();

    if (userVM.notificationsOn) {
      await apptVM.rescheduleTodayAndFuture(ns);
    }

    _didBootstrap = true;
    debugPrint('BOOT: notifications+range ready @ ${DateTime.now()}');
  }

  void _onSignedOut() {
    // Clear data & reset flags
    context.read<ClientCache>().clear();
    context.read<ServiceCache>().clear();
    context.read<AppointmentCache>().clear();
    context.read<ClientViewModel>().reset();
    context.read<ServiceViewModel>().reset();
    context.read<AppointmentViewModel>().resetOnAuthChange();
    context.read<UserViewModel>().onAuthChanged();
    _prefsInit = null;
    _didBootstrap = false;
  }

  @override
  void initState() {
    super.initState();

    final auth = context.read<FirebaseAuth>();

    _authSub = auth.authStateChanges().listen((user) async {
      if (user == null) {
        _onSignedOut();
      } else {
        await _onSignedIn();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _prefsInit ?? Future.value(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            home: const SizedBox.shrink(),
          );
        }

        final themeMode = context.select<UserViewModel, ThemeMode>(
          (vm) => vm.themeMode,
        );

        return MaterialApp.router(
          locale: const Locale('da'),
          supportedLocales: const [Locale('da'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          title: 'Aftaler & Regnskab',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: widget.router,
        );
      },
    );
  }
}
