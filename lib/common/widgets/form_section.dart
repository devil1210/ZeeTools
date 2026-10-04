import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Tarjeta con título que agrupa campos relacionados.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium + AppPadding.small, AppPadding.large, AppPadding.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
