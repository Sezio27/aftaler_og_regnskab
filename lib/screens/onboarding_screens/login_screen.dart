import 'package:aftaler_og_regnskab/navigation/app_router.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final logoPath = isDark ? 'assets/logo_white.png' : 'assets/logo_black.png';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  //Logo
                  SizedBox(
                    width: 200,
                    child: Image.asset(logoPath, fit: BoxFit.fitWidth),
                  ),

                  const SizedBox(height: 50),

                  //Buttons
                  SizedBox(
                    height: 48,
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

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 48,
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
