import 'package:aftaler_og_regnskab/domain/service_model.dart';
import 'package:aftaler_og_regnskab/ui/theme/typography.dart';
import 'package:aftaler_og_regnskab/ui/widgets/images/service_image.dart';
import 'package:aftaler_og_regnskab/utils/format_price.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CatalogServiceGrid extends StatelessWidget {
  const CatalogServiceGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = context.select<ServiceViewModel, List<ServiceModel>>(
      (vm) => vm.allServices,
    );

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: .80,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(blurRadius: 3, color: cs.onSurface.withAlpha(70)),
          ],
        ),
        child: ServiceItem(service: items[i]),
      ),
    );
  }
}

class ServiceItem extends StatelessWidget {
  const ServiceItem({super.key, required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        "serviceDetails",
        pathParameters: {'id': service.id!},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // image placeholder
          Expanded(child: ServiceImage(service.image)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name ?? "", style: AppTypography.b3),
                SizedBox(height: 12),
                Text(formatDKK(service.price), style: AppTypography.num3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
