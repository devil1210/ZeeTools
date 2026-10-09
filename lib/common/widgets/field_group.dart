import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Etiqueta sobre un grupo de opciones o una lista. [status] sustituye a [error], que tiñe la etiqueta.
class const FieldGroup({super.key, required final String label, required final Widget child, final String? status, final String? error}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium,
      children: [
        Text(
          [label, status ?? error].nonNulls.join(' · '),
          style: theme.textTheme.labelLarge?.copyWith(color: status == null && error != null ? theme.colorScheme.error : null),
        ),
        child,
      ],
    );
  }
}
