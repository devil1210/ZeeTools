import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Tarjeta con título que agrupa campos relacionados; [issues] cuenta los que tienen algún problema.
class const FormSection({super.key, required final String title, required final List<Widget> children, final IconData? icon, final Widget? trailing, final int issues = 0}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium + AppPadding.small, AppPadding.large, AppPadding.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              spacing: AppSpacing.medium + AppSpacing.small,
              children: [
                if (icon case final icon?)
                  DecoratedBox(
                    decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.medium)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.small + AppPadding.tiny),
                      child: Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (issues > 0) IssueCount(count: issues),
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

class const IssueCount({super.key, required final int count}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: count == 1 ? 'Un campo por revisar' : '$count campos por revisar',
      child: Badge(label: Text('$count')),
    );
  }
}
