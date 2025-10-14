import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static String routeName = '/login';

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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  //Logo
                  SizedBox(
                    width: size.width * 0.6,
                    child: Image.asset(
                      'assets/logo_black.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 26),

                  //Buttons
                  SizedBox(
                    height: 50,
                    child: CustomButton(
                      onTap: () {
                        context.read<OnboardingViewModel>().setAttemptLogin(
                          true,
                        );
                        context.goNamed(AppRoute.onboardingPhone.name);
                      },
                      text: 'Login',
                      textStyle: AppTypography.button1,
                      gradient: AppGradients.peach3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 50,
                    child: CustomButton(
                      onTap: () {
                        context.read<OnboardingViewModel>().setAttemptLogin(
                          false,
                        );
                        context.goNamed(AppRoute.onboardingPhone.name);
                      },
                      text: 'Tilmeld',
                      textStyle: AppTypography.button1,
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
