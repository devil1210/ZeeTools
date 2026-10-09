import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Una columna por defecto; a partir de [breakpoint] los campos van en fila.
class const ResponsiveRow({
  super.key,
  required final List<Widget> children,
  final List<int>? flex,
  // Ancho fijo por columna en fila; null reparte el resto según [flex].
  final List<double?>? widths,
  final double breakpoint = 900,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpacing.medium + AppSpacing.small, children: children);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
          children: [
            for (final (i, child) in children.indexed)
              if (widths?[i] case final width?) SizedBox(width: width, child: child) else Expanded(flex: flex?[i] ?? 1, child: child),
          ],
        );
      },
    );
  }
}
