import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:flutter/material.dart';

class ObEmailScreen extends StatefulWidget {
  const ObEmailScreen({super.key});
  static String routeName = '/email';

  @override
  State<ObEmailScreen> createState() => _ObEmailScreenState();
}

class _ObEmailScreenState extends State<ObEmailScreen> {
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();

    return OnboardingStepPage(
      progress: 0.2,
      title: 'Hvad er din email?',
      fields: [
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: AppTypography.onSurface(context, AppTypography.num1),
        ),
      ],
      enabled: false,
      onContinue: () {},
    );
  }
}
