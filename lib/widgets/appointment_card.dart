import 'package:aftaler_og_regnskab/theme/colors.dart';
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
  final String? time;
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
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 91),
      field: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          //mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon!,
              const SizedBox(width: 10),
            ],

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //Top row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.acTtitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (price != null)
                        Text(price!, style: AppTypography.num3),
                    ],
                  ),
                  const SizedBox(height: 12),

                  //Bottom row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Service (flex 5)
                      Expanded(
                        flex: 5,
                        child: Text(
                          subtitle ?? "ingen service valgt",
                          style: AppTypography.acSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // spacer (flex 1)
                      const Expanded(flex: 1, child: SizedBox.shrink()),

                      // timeblock (flex 2)
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          // allows this chunk to shrink without overflow
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule, size: 16),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(date ?? '', style: AppTypography.f1),
                                  Text(time ?? '', style: AppTypography.f1),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // spacer (flex 1)
                      const Expanded(flex: 1, child: SizedBox.shrink()),

                      // phone + text (flex 3)
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: const [
                            // phone (flex 1)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(
                                  Icons.phone_outlined,
                                  size: 24,
                                  color: AppColors.peach,
                                ),
                              ),
                            ),
                            // empty space (flex 1)
                            Expanded(child: SizedBox.shrink()),
                            // text (flex 1)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.peach,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
