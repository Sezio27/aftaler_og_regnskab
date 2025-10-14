import 'dart:async';

import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

class ObValidatePhoneScreen extends StatefulWidget {
  const ObValidatePhoneScreen({super.key});
  static String routeName = '/validatephone';
  @override
  State<ObValidatePhoneScreen> createState() => _ObValidatePhoneScreenState();
}

class _ObValidatePhoneScreenState extends State<ObValidatePhoneScreen> {
  final ctrl = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _loading = false;

  @override
  void dispose() {
    _timer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 30]) {
    setState(() => _secondsLeft = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _loading) return;
    _startResendCooldown();
    try {
      await context.read<OnboardingViewModel>().resendCode(
        context.read<FirebaseAuthMethods>(),
      );
    } catch (e) {
      _timer?.cancel();
      setState(() => _secondsLeft = 0);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunne ikke sende ny SMS: $e')));
    }
  }

  Future<void> _confirmAndRoute() async {
    if (_loading) return;
    setState(() => _loading = true);
    final vm = context.read<OnboardingViewModel>();
    final auth = context.read<FirebaseAuthMethods>();

    await vm.confirmAndRoute(
      smsCode: ctrl.text,
      auth: auth,
      goHome: () async {
        if (!mounted) return;
        context.goNamed(AppRoute.home.name);
      },
      goOnboarding: () async {
        if (!mounted) return;
        context.goNamed(AppRoute.onboardingEmail.name);
      },
      loginNoAccount: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Telefonnummeret er ikke tilknyttet en bruger.'),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
        await vm.signOut();
        if (!mounted) return;
        vm.setAttemptLogin(false);
        context.goNamed(AppRoute.login.name);
      },
      onError: (err) async {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();

    final canContinue = ctrl.text.length == 6 && !_loading;
    final cs = Theme.of(context).colorScheme;

    final baseUnderline = BorderSide(
      color: cs.onSurface.withOpacity(0.75),
      width: 1,
    );

    final focusUnderline = BorderSide(color: cs.primary, width: 2);
    final defaultPinTheme = PinTheme(
      width: 40,
      height: 52,
      textStyle: AppTypography.numBig,
      decoration: BoxDecoration(border: Border(bottom: baseUnderline)),
    );
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(border: Border(bottom: focusUnderline)),
    );

    return OnboardingStepPage(
      progress: 0.1,
      title: "Indtast din kode",
      subtitle: vm.fullPhoneForSession.isEmpty ? null : vm.fullPhoneForSession,
      fields: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: Pinput(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            length: 6,
            controller: ctrl,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),

        // Send igen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modtog du ikke en besked? Prøv igen.',
                style: AppTypography.b2,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (_secondsLeft == 0 && !_loading) ? _resend : null,
                    child: Text(
                      _secondsLeft == 0
                          ? 'Send igen'
                          : 'Send igen (${_secondsLeft}s)',
                      style: AppTypography.b2.copyWith(
                        color: _secondsLeft == 0 ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      enabled: canContinue,
      isLoading: _loading,
      onContinue: _confirmAndRoute,
    );
  }
}
