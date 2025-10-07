import 'package:aftaler_og_regnskab/app_router.dart';
import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = AppTypography.settingsTitle;
    final labelStyle = AppTypography.settingsLabel;
    final valueStyle = AppTypography.settingsValue;

    var businessInfo = [
      Text("Forretningsinformation", style: titleStyle),
      const SizedBox(height: 26),
      Text("Forretningsnavn", style: labelStyle),
      const SizedBox(height: 10),
      Text("MyPhung", style: valueStyle),
      const SizedBox(height: 20),
      Text("Adresse", style: labelStyle),
      const SizedBox(height: 10),
      Text("Østergade 25, 1100 København K", style: valueStyle),
    ];

    var preferences = [
      Text("Præferencer", style: titleStyle),
      const SizedBox(height: 26),
      Text("Mørk tilstand", style: labelStyle),
      const SizedBox(height: 22),
      Text("   Skift til mørkt tema", style: valueStyle),
      const SizedBox(height: 30),
      Text("Notifikationer", style: labelStyle),
      const SizedBox(height: 22),
      Text("   Aftalepåmindelser", style: valueStyle),
      const SizedBox(height: 30),
      Text("   Betaling forfalden", style: valueStyle),
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

    Widget buildSection(List<Widget> section) {
      return CustomCard(
        field: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: section,
          ),
        ),
      );
    }

    final sections = <Widget>[
      buildSection(businessInfo),
      buildSection(preferences),
      buildSection(clients),
      buildSection(dataPrivacy),
    ];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  for (var i = 0; i < sections.length; i++) ...[
                    sections[i],
                    if (i != sections.length - 1) const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: ShapeDecoration(
                          color: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {},
                          customBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (rect) =>
                                      AppGradients.peach3Reverse
                                          .createShader(rect),
                                  blendMode: BlendMode.srcIn,
                                  child: Icon(
                                    Icons.logout,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }
}
