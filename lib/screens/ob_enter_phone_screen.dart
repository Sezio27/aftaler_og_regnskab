import 'package:aftaler_og_regnskab/screens/ob_validate_phone_screen.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_button.dart';
import 'package:aftaler_og_regnskab/widgets/onboarding_step_page.dart';
import 'package:aftaler_og_regnskab/widgets/step__bar.dart';
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
  String dial = '+45';
  final ctrl = TextEditingController();
  bool _loading = false;

  Future<void> _sendCode() async {
    final fullPhone = '$dial${ctrl.text}';
    setState(() => _loading = true);
    try {
      // Dart 3 records version:
      final (verificationId, resendToken) = await context
          .read<FirebaseAuthMethods>()
          .startPhoneVerification(fullPhone);

      // Navigate and pass everything the next screen needs
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        ObValidatePhoneScreen.routeName,
        arguments: {
          'fullPhone': fullPhone,
          'verificationId': verificationId,
          'resendToken': resendToken,
        },
      );
    } catch (e) {
      // show a lightweight error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = ctrl.text.length >= 8;
    final borderColor = Theme.of(context).colorScheme.onSurface;
    final fullPhone = '$dial${ctrl.text}';

    return OnboardingStepPage(
      progress: 0.02,
      title: 'Hvad er dit nummer?',
      fields: [
        Padding(
          padding: EdgeInsets.only(left: 18, right: 26),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1) Country picker with its own underline
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 8,
                  ), // lift text above the line
                  child: InkWell(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: true,
                        onSelect: (c) => setState(() {
                          iso = c.countryCode;
                          dial = '+${c.phoneCode}';
                        }),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$iso $dial',
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.onSurface(
                        context,
                        AppTypography.num1,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none, // <- no built-in underline
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Vi vil sende dig en besked, for at bekræfte, at det virkelig er dig.',
            style: AppTypography.onSurface(context, AppTypography.b2),
          ),
        ),
        const Spacer(),
      ],
      enabled: !_loading && canContinue,
      onContinue: _sendCode,
    );
  }
}
