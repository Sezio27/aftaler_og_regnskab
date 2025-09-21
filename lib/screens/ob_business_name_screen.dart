import 'package:aftaler_og_regnskab/screens/ob_business_location_screen.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/ob_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ObBusinessNameScreen extends StatefulWidget {
  const ObBusinessNameScreen({super.key});
  static String routeName = '/forretningnavn';

  @override
  State<ObBusinessNameScreen> createState() => _ObForretningNavnScreenState();
}

class _ObForretningNavnScreenState extends State<ObBusinessNameScreen> {
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<OnboardingViewModel>();
      ctrl.text = vm.businessName ?? '';
    });

    ctrl.addListener(
      () => context.read<OnboardingViewModel>().setBusinessName(ctrl.text),
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
      (vm) => vm.isBusinessNameValid,
    );
    return OnboardingStepPage(
      progress: 0.75,
      title: 'Hvad hedder din forretning?',
      fields: [
        ObTextfield(
          hintText: 'Indtast forretningsnavn',
          controller: ctrl,
          autofillHints: const [AutofillHints.organizationName],
        ),
      ],
      enabled: canContinue,
      onContinue: () {
        Navigator.pushNamed(context, ObBusinessLocationScreen.routeName);
      },
    );
  }
}
