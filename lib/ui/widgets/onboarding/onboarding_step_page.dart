import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/ui/widgets/buttons/custom_button.dart';
import 'package:aftaler_og_regnskab/ui/widgets/onboarding/step__bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingStepPage extends StatelessWidget {
  final double progress;
  final String title;
  final String? subtitle;
  final Widget fields;
  final String buttonText;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onContinue;

  const OnboardingStepPage({
    super.key,
    required this.progress,
    required this.title,
    this.subtitle,
    required this.fields,
    this.buttonText = 'Fortsæt',
    required this.enabled,
    this.isLoading = false,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: TapRegion(
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepBar(value: progress),

                const SizedBox(height: 16),

                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(title, style: AppTypography.h2),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    child: Text(subtitle!, style: AppTypography.num1),
                  ),
                ],

                const SizedBox(height: 40),

                fields,
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    onTap: (enabled && !isLoading) ? onContinue : () {},
                    text: isLoading ? '' : buttonText,
                    textStyle: AppTypography.button1.copyWith(
                      color: enabled
                          ? Colors.white
                          : Colors.white.withAlpha(180),
                    ),
                    gradient: enabled ? AppGradients.peach3 : null,
                    color: enabled ? null : cs.onSecondary.withAlpha(120),
                    loading: isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
