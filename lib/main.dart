import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/firebase_options.dart';
import 'package:aftaler_og_regnskab/screens/home_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/login_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_location_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_business_name_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_email_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_name.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_validate_phone_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/services/user_repository.dart';
import 'package:aftaler_og_regnskab/theme/app_theme.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
        Provider<UserRepository>(create: (_) => UserRepository()),
        ChangeNotifierProvider<OnboardingViewModel>(
          create: (ctx) => OnboardingViewModel(ctx.read<UserRepository>()),
        ),
        Provider<FirebaseAuthMethods>(
          create: (_) => FirebaseAuthMethods(FirebaseAuth.instance),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('da'),
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
        routerConfig: router,
      ),
    );
  }
}
