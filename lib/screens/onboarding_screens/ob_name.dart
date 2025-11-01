import 'package:aftaler_og_regnskab/navigation/app_router.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding/ob_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding/onboarding_step_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ObNameScreen extends StatefulWidget {
  const ObNameScreen({super.key});
  static String routeName = '/name';

  @override
  State<ObNameScreen> createState() => _ObNameScreenState();
}

class _ObNameScreenState extends State<ObNameScreen> {
  final ctrlFirst = TextEditingController();
  final ctrlLast = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Pre-fill from VM so values persist if user navigates back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<OnboardingViewModel>();
      ctrlFirst.text = vm.firstName ?? '';
      ctrlLast.text = vm.lastName ?? '';
    });

    ctrlFirst.addListener(
      () => context.read<OnboardingViewModel>().setFirstName(ctrlFirst.text),
    );
    ctrlLast.addListener(
      () => context.read<OnboardingViewModel>().setLastName(ctrlLast.text),
    );
  }

  @override
  void dispose() {
    ctrlFirst.dispose();
    ctrlLast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = context.select<OnboardingViewModel, bool>(
      (vm) => vm.isFirstNameValid && vm.isLastNameValid,
    );

    return OnboardingStepPage(
      progress: 0.45,
      title: 'Hvad er dit navn?',
      fields: Column(
        children: [
          ObTextfield(
            hintText: 'Indtast fornavn',
            controller: ctrlFirst,
            autofillHints: const [AutofillHints.givenName],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: const SizedBox(height: 30),
          ),
          ObTextfield(
            hintText: 'Indtast efternavn',
            controller: ctrlLast,
            autofillHints: const [AutofillHints.familyName],
          ),
        ],
      ),
      enabled: canContinue,
      onContinue: () {
        context.goNamed(AppRoute.onboardingBusinessName.name);
      },
    );
  }
}
