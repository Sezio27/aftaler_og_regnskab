import 'package:aftaler_og_regnskab/screens/ob_enter_phone_screen.dart';
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
  final VoidCallback onContinue;

  const OnboardingStepPage({
    super.key,
    required this.progress,
    required this.title,
    this.subtitle,
    required this.fields,
    this.buttonText = 'Fortsæt',
    required this.enabled,
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
                child: CustomButton(
                  onTap: enabled ? onContinue : () {},
                  text: 'Fortsæt',
                  textStyle: AppTypography.button1,
                  gradient: enabled ? AppGradients.peach3 : null,
                  color: enabled ? null : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
