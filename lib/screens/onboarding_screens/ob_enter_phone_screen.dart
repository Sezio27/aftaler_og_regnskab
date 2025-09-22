import 'package:aftaler_og_regnskab/screens/onboarding_screens/ob_validate_phone_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';

import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/showSnackBar.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';

import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ObEnterPhoneScreen extends StatefulWidget {
  const ObEnterPhoneScreen({super.key});
  static String routeName = '/regphone';
  @override
  State<ObEnterPhoneScreen> createState() => _ObEnterPhoneScreenState();
}

class _ObEnterPhoneScreenState extends State<ObEnterPhoneScreen> {
  String iso = 'DK';
  final ctrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<OnboardingViewModel>();
      ctrl.text = vm.currentNational;
    });

    ctrl.addListener(() {
      final vm = context.read<OnboardingViewModel>();
      vm.setPhoneWithDial(dial: vm.currentDial, national: ctrl.text);
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final vm = context.read<OnboardingViewModel>();

      await vm.startPhoneVerification(context.read<FirebaseAuthMethods>());
      if (!mounted) return;

      Navigator.pushNamed(context, ObValidatePhoneScreen.routeName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: cs.onSurface, width: 1),
    );

    final canContinue = context.select<OnboardingViewModel, bool>(
      (vm) => !_loading && vm.isPhoneValid,
    );

    final vm = context.watch<OnboardingViewModel>();

    return OnboardingStepPage(
      progress: 0.02,
      title: vm.attemptLogin ? "Indtast dit nummer" : 'Hvad er dit nummer?',
      isLoading: _loading,
      fields: [
        Padding(
          padding: EdgeInsets.only(left: 18, right: 26),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: cs.onSurface, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: true,
                        onSelect: (c) {
                          setState(() => iso = c.countryCode);
                          vm.setCurrentDial('+${c.phoneCode}');
                        },
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$iso ${vm.currentDial}',
                          style: AppTypography.onSurface(
                            context,
                            AppTypography.num1,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: AppTypography.onSurface(
                    context,
                    AppTypography.phoneInput,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    enabledBorder: underline,
                    focusedBorder: underline,
                    disabledBorder: underline,
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    labelStyle: TextStyle(color: cs.onSurface),
                    floatingLabelStyle: TextStyle(color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Vi vil sende dig en besked, for at bekræfte, at det virkelig er dig.',
            style: AppTypography.onSurface(context, AppTypography.b2),
          ),
        ),
        const Spacer(),
      ],
      enabled: canContinue,
      onContinue: _sendCode,
    );
  }
}
