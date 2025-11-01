import 'package:aftaler_og_regnskab/theme/colors.dart';
import 'package:aftaler_og_regnskab/theme/typography.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/widgets/avatar.dart';
import 'package:aftaler_og_regnskab/widgets/cards/custom_card.dart';
import 'package:flutter/material.dart';

class AppointmentCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? color;
  final String? subtitlePrice;
  final Widget? mainIcon;
  final Avatar? avatar;
  final String? date;
  final String? time;
  final double? price;
  final Widget? endingIcons;
  final VoidCallback? onTap;

  const AppointmentCard({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitlePrice,
    this.mainIcon,
    this.date,
    this.price,
    this.endingIcons,
    this.color = AppColors.shadowColor,
    this.time,
    this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 90),
      shadow: [
        BoxShadow(
          color: color!,
          spreadRadius: 0,
          blurRadius: 4,
          offset: Offset(-5, 0),
          blurStyle: BlurStyle.inner,
        ),
      ],

      field: GestureDetector(
        behavior: HitTestBehavior.opaque, // ✅ full card is tappable
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (avatar != null) ...[avatar!, const SizedBox(width: 10)],

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: AppTypography.acTtitle,
                          overflow: TextOverflow.ellipsis,
                        ),

                        Text(formatDKK(price), style: AppTypography.num3),
                      ],
                    ),
                    const SizedBox(height: 12),

                    //Bottom row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (subtitle?.trim().isNotEmpty ?? false)
                                ? subtitle!.trim()
                                : '---',
                            style: AppTypography.acSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        Row(
                          children: [
                            Row(
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
                                SizedBox(width: 20),
                                Row(
                                  children: const [
                                    // phone (flex 1)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Icon(
                                        Icons.phone_outlined,
                                        size: 24,
                                        color: AppColors.peach,
                                      ),
                                    ),
                                    // empty space (flex 1)
                                    SizedBox(width: 20),
                                    // text (flex 1)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        color: AppColors.peach,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
