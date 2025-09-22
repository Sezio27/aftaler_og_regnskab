import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_name.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/ob_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ObEmailScreen extends StatefulWidget {
  const ObEmailScreen({super.key});
  static String routeName = '/email';

  @override
  State<ObEmailScreen> createState() => _ObEmailScreenState();
}

class _ObEmailScreenState extends State<ObEmailScreen> {
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<OnboardingViewModel>();
      ctrl.text = vm.email ?? '';
    });

    ctrl.addListener(
      () => context.read<OnboardingViewModel>().setEmail(ctrl.text),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = context.select<OnboardingViewModel, bool>(
      (vm) => vm.isEmailValid,
    );

    return OnboardingStepPage(
      progress: 0.25,
      title: 'Hvad er din email?',
      fields: [
        ObTextfield(
          hintText: 'Indtast e-mail',
          controller: ctrl,
          autofillHints: const [AutofillHints.email],
        ),
      ],
      enabled: canContinue,
      onContinue: () {
        Navigator.pushNamed(context, ObNameScreen.routeName);
      },
    );
  }
}
