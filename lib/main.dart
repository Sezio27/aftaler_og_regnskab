// main.dart
import 'dart:async';
import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/data/appointment_repository.dart';
import 'package:aftaler_og_regnskab/data/checklist_repository.dart';
import 'package:aftaler_og_regnskab/data/client_repository.dart';
import 'package:aftaler_og_regnskab/data/service_repository.dart';
import 'package:aftaler_og_regnskab/data/user_repository.dart';
import 'package:aftaler_og_regnskab/firebase_options.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/services/image_storage.dart';
import 'package:aftaler_og_regnskab/theme/app_theme.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/checklist_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
// ... your other imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('da');
  final appRouter = createRouter();
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

        ChangeNotifierProvider(
          create: (ctx) => ClientViewModel(
            ctx.read<ClientRepository>(),
            ctx.read<ImageStorage>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ServiceViewModel(
            ctx.read<ServiceRepository>(),
            ctx.read<ImageStorage>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChecklistViewModel(ctx.read<ChecklistRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final apptRepo = ctx.read<AppointmentRepository>();
            final serviceRepo = ctx.read<ServiceRepository>();
            final clientRepo = ctx.read<ClientRepository>();
            final storage = ctx.read<ImageStorage>();
            return AppointmentViewModel(
              apptRepo,
              storage,
              fetchClient: (id) => clientRepo.getClientOnce(id),
              fetchService: (id) => serviceRepo.getServiceOnce(id),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) => OnboardingViewModel(ctx.read<UserRepository>()),
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

class _AppBootstrapState extends State<_AppBootstrap> {
  StreamSubscription<User?>? _authSub;
  bool _didBootstrap = false;

  void _bootstrapYearRange() {
    final vm = context.read<AppointmentViewModel>();
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    vm.setActiveRange(start, end, label: 'AppBootstrap:initYearRange');
  }

  @override
  void initState() {
    super.initState();

    final auth = context.read<FirebaseAuth>();

    // If user is already signed in at app start
    if (auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_didBootstrap) {
          _bootstrapYearRange();
          _didBootstrap = true;
        }
      });
    }

    // Also react to later sign-ins
    _authSub = auth.authStateChanges().listen((user) {
      if (user != null) {
        if (!_didBootstrap) {
          _bootstrapYearRange();
          _didBootstrap = true;
        } else {
          // Switching accounts? Re-bootstrap cleanly
          _bootstrapYearRange();
        }
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
      themeMode: ThemeMode.system,
      routerConfig: widget.router,
    );
  }
}
