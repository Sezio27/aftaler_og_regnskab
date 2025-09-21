import 'package:aftaler_og_regnskab/screens/home_screen.dart';
import 'package:aftaler_og_regnskab/screens/ob_name.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/ob_textfield.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ObBusinessLocationScreen extends StatefulWidget {
  const ObBusinessLocationScreen({super.key});
  static String routeName = '/forretninglokation';

  @override
  State<ObBusinessLocationScreen> createState() =>
      _ObForretningNavnScreenState();
}

class _ObForretningNavnScreenState extends State<ObBusinessLocationScreen> {
  final ctrl_address = TextEditingController();
  final ctrl_city = TextEditingController();
  final ctrl_postal = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill from VM so values persist if user navigates back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<OnboardingViewModel>();
      ctrl_address.text = vm.address ?? '';
      ctrl_city.text = vm.city ?? '';
      ctrl_postal.text = vm.postal ?? '';
    });

    ctrl_address.addListener(
      () => context.read<OnboardingViewModel>().setAddress(ctrl_address.text),
    );
    ctrl_city.addListener(
      () => context.read<OnboardingViewModel>().setCity(ctrl_city.text),
    );
    ctrl_postal.addListener(
      () => context.read<OnboardingViewModel>().setPostal(ctrl_postal.text),
    );
  }

  @override
  void dispose() {
    ctrl_address.dispose();
    ctrl_city.dispose();
    ctrl_postal.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    assert(user != null, 'User not signed in before save()');
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final vm = context.read<OnboardingViewModel>();

      if (!vm.isEmailValid ||
          !vm.isFirstNameValid ||
          !vm.isLastNameValid ||
          !vm.isBusinessNameValid ||
          !vm.isAddressValid ||
          !vm.isCityValid ||
          !vm.isPostalValid ||
          !vm.isPhoneValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Udfyld venligst alle felter')),
        );
        return;
      }

      await vm.save();
      vm.clear();
      debugPrint('Save OK');

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunne ikke gemme: $e')));
      debugPrint('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = context.select<OnboardingViewModel, bool>(
      (vm) => vm.isAddressValid && vm.isCityValid && vm.isPostalValid,
    );

    return OnboardingStepPage(
      progress: 0.95,
      title: 'Hvad ligger din forretning?',
      fields: [
        ObTextfield(
          hintText: 'Indtast addresse',
          controller: ctrl_address,
          autofillHints: const [AutofillHints.postalAddress],
        ),
        const SizedBox(height: 40),
        ObTextfield(
          hintText: 'Indtast by',
          controller: ctrl_city,
          autofillHints: const [AutofillHints.addressCity],
        ),
        const SizedBox(height: 40),
        ObTextfield(
          hintText: 'Indtast postnummer',
          controller: ctrl_postal,
          autofillHints: const [AutofillHints.postalCode],
          keyboardType: TextInputType.number,
        ),
      ],
      enabled: canContinue,
      isLoading: _saving,
      onContinue: _finishOnboarding,
    );
  }
}
