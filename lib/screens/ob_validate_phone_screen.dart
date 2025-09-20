import 'dart:async';

import 'package:aftaler_og_regnskab/screens/ob_email_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:flutter/material.dart';
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

  String _fullPhone = '';
  String? _verificationId;
  int? _resendToken;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    final args = (ModalRoute.of(context)!.settings.arguments as Map?) ?? {};
    _fullPhone = (args['fullPhone'] as String?) ?? _fullPhone;
    _verificationId ??= args['verificationId'] as String?;
    _resendToken ??= args['resendToken'] as int?;
    _didInit = true;
  }

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
    _startResendCooldown();

    try {
      final auth = context.read<FirebaseAuthMethods>();

      // Key line: pass the previous resend token so Firebase allows immediate resend
      final (newVerificationId, newResendToken) = await auth
          .startPhoneVerification(
            _fullPhone,
            forceResendingToken: _resendToken,
            timeout: const Duration(seconds: 60),
          );

      if (!mounted) return;
      setState(() {
        _verificationId = newVerificationId;
        _resendToken = newResendToken;
      });
    } catch (e) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _secondsLeft = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunne ikke sende ny SMS: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = ctrl.text.length == 6;
    final bc = Theme.of(context).colorScheme;

    final baseUnderline = BorderSide(
      color: bc.onSurface.withOpacity(0.75),
      width: 1,
    );
    final focusUnderline = BorderSide(color: bc.primary, width: 2);
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
      subtitle: _fullPhone,
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
                    onTap: _secondsLeft == 0 ? () => _resend() : null,
                    child: Text(
                      _secondsLeft == 0
                          ? 'Send igen'
                          : 'Send igen (${_secondsLeft}s)',
                      style: AppTypography.b2.copyWith(
                        color: _secondsLeft == 0
                            ? bc.primary
                            : bc.onSurface.withValues(alpha: 1),
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
      onContinue: () async {
        if (_verificationId == null) return;
        try {
          await context.read<FirebaseAuthMethods>().confirmSmsCode(
            verificationId: _verificationId!,
            smsCode: ctrl.text,
          );
          if (!mounted) return;
          Navigator.pushNamed(context, ObEmailScreen.routeName);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
    );
  }
}
