import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/viewModel/user_view_model.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remindersOn = true;
  bool _paymentOn = true;
  @override
  Widget build(BuildContext context) {
    // UI-only toggles for now (no backend logic)

    final titleStyle = AppTypography.settingsTitle;
    final labelStyle = AppTypography.settingsLabel;
    final valueStyle = AppTypography.settingsValue;

    final userVM = context.watch<UserViewModel>();
    final isDark = userVM.themeMode == ThemeMode.dark;

    final modeLabel = isDark ? "Mørk tilstand" : "Lys tilstand";
    final modeAction = isDark
        ? "   Skift til lyst tema"
        : "   Skift til mørkt tema";
    final businessName = (userVM.businessName.isNotEmpty)
        ? userVM.businessName
        : '---';
    final addressParts = <String>[
      userVM.address,
      if (userVM.postal.trim().isNotEmpty) userVM.postal,
      if (userVM.city.trim().isNotEmpty) userVM.city,
    ].where((s) => s.trim().isNotEmpty).toList();

    final addressCombined = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : '---';

    var businessInfo = [
      Text("Forretningsinformation", style: titleStyle),
      const SizedBox(height: 26),
      Text("Forretningsnavn", style: labelStyle),
      const SizedBox(height: 10),
      Text(businessName, style: valueStyle),
      const SizedBox(height: 20),
      Text("Adresse", style: labelStyle),
      const SizedBox(height: 10),
      Text(addressCombined, style: valueStyle),
    ];

    var preferences = [
      Text("Præferencer", style: titleStyle),
      const SizedBox(height: 26),
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(modeLabel, style: labelStyle),
                  const SizedBox(height: 22),
                  Text(modeAction, style: valueStyle),
                ],
              ),
            ),
            const _ThemeModeButton(),
          ],
        ),
      ),

      const SizedBox(height: 30),
      Text("Notifikationer", style: labelStyle),
      const SizedBox(height: 22),
      // Aftalepåmindelser
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          children: [
            Expanded(child: Text("   Aftalepåmindelser", style: valueStyle)),
            _PeachToggleIcon(
              isOn: _remindersOn,
              icon: Icons.check,
              onTap: () => setState(() => _remindersOn = !_remindersOn),
            ),
          ],
        ),
      ),

      const SizedBox(height: 30),

      // Betalingsnotifikationer
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          children: [
            Expanded(
              child: Text("   Betalingsnotifikationer", style: valueStyle),
            ),
            _PeachToggleIcon(
              isOn: _paymentOn,
              icon: Icons.check,
              onTap: () => setState(() => _paymentOn = !_paymentOn),
            ),
          ],
        ),
      ),
    ];

    var clients = [
      Text("Klienter", style: titleStyle),
      const SizedBox(height: 26),
      Row(
        children: [
          Icon(Icons.people_outline_outlined),
          SizedBox(width: 12),
          InkWell(
            onTap: () => context.pushNamed(AppRoute.allClients.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text("Se klienter", style: labelStyle),
            ),
          ),
        ],
      ),
    ];

    var dataPrivacy = [
      Text("Data og Privatliv", style: titleStyle),
      const SizedBox(height: 26),
      Text("Eksporter data som CSV", style: labelStyle),
      const SizedBox(height: 22),
      Text("Privatlivspolitik", style: labelStyle),
      const SizedBox(height: 22),
      Text("Hjælp og suppoort", style: labelStyle),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section: Forretningsinformation
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [...businessInfo],
                ),
              ),
            ),

            const SizedBox(height: 16),
            CustomCard(
              field: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [...preferences],
                ),
              ),
            ),

            const SizedBox(height: 16),

            CustomCard(
              field: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [...clients],
                ),
              ),
            ),

            const SizedBox(height: 16),

            CustomCard(
              field: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [...dataPrivacy],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: ShapeDecoration(
                    color: Colors.transparent, // or a subtle bg if you want
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: InkWell(
                    onTap: () async {
                      final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Log ud?'),
                              content: const Text(
                                'Du kan altid logge ind igen.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Annullér'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Log ud'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!confirm) return;

                      await context.read<FirebaseAuthMethods>().signOut(
                        context,
                      );
                    },

                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (rect) =>
                                AppGradients.peach3Reverse.createShader(rect),
                            blendMode: BlendMode.srcIn,
                            child: Icon(
                              Icons.logout,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text("Log ud", style: AppTypography.b1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserViewModel>();
    final isDark = vm.themeMode == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;

    final Color bg = isDark ? cs.primary : AppColors.peachBackground;
    final Color icon = isDark ? cs.onPrimary : cs.primary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          final next = isDark ? ThemeMode.light : ThemeMode.dark;
          context.read<UserViewModel>().setThemeMode(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              // subtle lift in light mode only
              if (!isDark)
                const BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.nightlight_round, // moon-ish
            size: 16,
            color: icon,
          ),
        ),
      ),
    );
  }
}

class _PeachToggleIcon extends StatelessWidget {
  final bool isOn;
  final IconData icon;
  final VoidCallback onTap;
  final Color? onColor; // defaults to theme.primary
  final Color? offColor; // defaults to AppColors.peachBackground
  final double size;

  const _PeachToggleIcon({
    required this.isOn,
    required this.icon,
    required this.onTap,
    this.onColor,
    this.offColor,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = isOn
        ? (onColor ?? cs.primary)
        : (offColor ?? AppColors.peachBackground);
    final Color ic = isOn ? cs.onPrimary : cs.primary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              if (!isOn)
                const BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: size * 0.5, color: ic),
        ),
      ),
    );
  }
}
