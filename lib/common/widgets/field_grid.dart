import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Rejilla de [columns] columnas iguales en la que cada hijo ocupa las que indica [spans]
// (una si no se indica), de modo que las filas de una misma sección quedan alineadas.
// Si no caben columnas de [minCellWidth], se usan menos y los hijos pasan a la fila siguiente.
class const FieldGrid({super.key, required final List<Widget> children, final int columns = 3, final List<int>? spans, final double minCellWidth = 200}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.medium;
        final fit = ((constraints.maxWidth + gap) / (minCellWidth + gap)).floor().clamp(1, columns);
        final cell = (constraints.maxWidth - gap * (fit - 1)) / fit;
        final rows = <List<(Widget, int)>>[];
        var used = fit;
        for (final (i, child) in children.indexed) {
          final span = min(spans?[i] ?? 1, fit);
          if (used + span > fit) {
            rows.add([]);
            used = 0;
          }
          rows.last.add((child, span));
          used += span;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            for (final row in rows)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: gap,
                children: [
                  for (final (child, span) in row) SizedBox(width: cell * span + gap * (span - 1), child: child),
                ],
              ),
          ],
        );
      },
    );
  }
}
