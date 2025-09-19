import 'package:aftaler_og_regnskab/screens/phone_screen.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            // centers the whole column vertically
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min, // shrink to content
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  SizedBox(
                    width: size.width * 0.6,
                    child: Image.asset(
                      'assets/logo_black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Buttons just under the logo
                  SizedBox(
                    height: 60,
                    child: CustomButton(
                      onTap: () {
                        Navigator.pushNamed(context, PhoneScreen.routeName);
                      },
                      text: 'Login',
                      gradient: AppGradients.peach3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 60,
                    child: CustomButton(
                      onTap: () {
                        // TODO: sign-up flow
                      },
                      text: 'Tilmeld',
                      gradient: AppGradients.peach3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
