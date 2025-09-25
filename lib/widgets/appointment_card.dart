import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/widgets/custom_card.dart';
import 'package:flutter/material.dart';

class AppointmentCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? color;
  final String? subtitlePrice;
  final Widget? mainIcon;
  final Icon? leadingIcon;
  final String? date;
  final String? price;
  final Widget? endingIcons;

  const AppointmentCard({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitlePrice,
    this.mainIcon,
    this.leadingIcon,
    this.date,
    this.price,
    this.endingIcons,
    this.color,
  });

  Widget _timeBlock() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // icon centers to text-column
        children: [
          const Icon(Icons.schedule, size: 17),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('16/10', style: AppTypography.f1),
              Text('11:00', style: AppTypography.f1),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 91),
      field: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: IntrinsicHeight(
          child: Row(
            spacing: 20,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 10),
              ],

              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sarah Johnson", style: AppTypography.acTtitle),
                  Text("Bryllups Makeup", style: AppTypography.acSubtitle),
                ],
              ),

              _timeBlock(),
            ],
          ),
        ),
      ),
    );
  }
}
