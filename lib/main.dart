import 'package:aftaler_og_regnskab/firebase_options.dart';
import 'package:aftaler_og_regnskab/screens/home_screen.dart';
import 'package:aftaler_og_regnskab/screens/login_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_business_location_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_business_name_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_email_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_name.dart';
import 'package:aftaler_og_regnskab/screens/ob_validate_phone_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/services/user_repository.dart';
import 'package:aftaler_og_regnskab/theme/app_theme.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Aftaler & Regnskab',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
        routes: {
          LoginScreen.routeName: (context) => const LoginScreen(),
          HomeScreen.routeName: (context) => const HomeScreen(),
          ObEnterPhoneScreen.routeName: (context) => const ObEnterPhoneScreen(),
          ObValidatePhoneScreen.routeName: (context) =>
              const ObValidatePhoneScreen(),
          ObEmailScreen.routeName: (context) => const ObEmailScreen(),
          ObNameScreen.routeName: (context) => const ObNameScreen(),
          ObBusinessNameScreen.routeName: (context) =>
              const ObBusinessNameScreen(),
          ObBusinessLocationScreen.routeName: (context) =>
              const ObBusinessLocationScreen(),
        },
      ),
    );
  }
}

/// Auto-login gate:
/// - Not signed in: LoginScreen
/// - Signed in: check Firestore doc → Home if exists, otherwise onboarding
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }
        // User is signed in → check if profile exists
        return FutureBuilder<bool>(
          future: context.read<UserRepository>().userDocExists(uid: user.uid),
          builder: (context, fs) {
            if (fs.connectionState != ConnectionState.done) {
              return const _Splash();
            }
            final exists = fs.data == true;
            // If you prefer to start at phone again for new users, swap ObEmailScreen with ObEnterPhoneScreen
            return exists ? const HomeScreen() : const ObEmailScreen();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
