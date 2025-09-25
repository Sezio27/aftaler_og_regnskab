import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_enter_phone_screen.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/step__bar.dart';
import 'package:flutter/material.dart';

class OnboardingStepPage extends StatelessWidget {
  final double progress;
  final String title;
  final String? subtitle;
  final List<Widget> fields;
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // progress
              StepBar(value: progress),

              const SizedBox(height: 16),

              //Back button
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),

              const SizedBox(height: 12),

              //Question - Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(title, style: AppTypography.h2),
              ),

              // Optional subtitle
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

              ...fields,

              const Spacer(),
              //Continue button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52, // same visual height as your button
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The button (disabled while loading or not enabled)
                      CustomButton(
                        onTap: (enabled && !isLoading) ? onContinue : () {},
                        text: isLoading ? '' : buttonText,
                        textStyle: AppTypography.button1,
                        gradient: enabled ? AppGradients.peach3 : null,
                        color: enabled ? null : Colors.black26,
                      ),

                      // Progress overlay
                      if (isLoading)
                        const IgnorePointer(
                          // block taps during loading
                          ignoring: true,
                          child: DecoratedBox(
                            decoration: BoxDecoration(), // transparent overlay
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
