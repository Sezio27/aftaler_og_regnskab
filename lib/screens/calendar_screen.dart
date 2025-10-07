import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 24),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: const Center(
              child: Text('Calendar'),
            ),
          ),
        ),
      ],
    );
  }
}
