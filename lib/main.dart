import 'package:aftaler_og_regnskab/firebase_options.dart';
import 'package:aftaler_og_regnskab/screens/home_screen.dart';
import 'package:aftaler_og_regnskab/screens/login_screen.dart';
import 'package:aftaler_og_regnskab/screens/phone_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthMethods>(
          create: (_) => FirebaseAuthMethods(FirebaseAuth.instance),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<FirebaseAuthMethods>().authState,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Firebase Auth Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const AuthWrapper(),
        routes: {
          PhoneScreen.routeName: (context) => const PhoneScreen(),
        },
        // 👇 these are NOT inside `routes`
        onUnknownRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
        onGenerateRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}