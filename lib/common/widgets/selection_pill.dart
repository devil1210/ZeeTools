import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Opción conmutable con forma de rectángulo redondeado; la selección se indica
// solo con el color de fondo. `child` hereda el color vía [IconTheme]/
// [DefaultTextStyle]; para conservar uno propio, fijarlo en el hijo. `dense` la
// compacta para filas de herramientas.
class SelectionPill extends StatelessWidget {
  const SelectionPill({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
    this.color,
    this.dense = false,
    this.tooltip,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final bool dense;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = switch (color) {
      _ when !selected => cs.surfaceContainer,
      null => cs.primaryContainer,
      final accent => accent.withValues(alpha: 0.24),
    };
    final foreground = !selected ? cs.onSurfaceVariant : (color ?? cs.onPrimaryContainer);
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = ((dense ? textTheme.labelSmall : textTheme.labelLarge) ?? const TextStyle()).copyWith(color: foreground, fontWeight: dense ? FontWeight.w600 : null);
    final radius = BorderRadius.circular(AppRadius.small);

    final pill = Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: dense ? const EdgeInsets.symmetric(horizontal: AppPadding.small + AppPadding.tiny, vertical: AppPadding.tiny) : const EdgeInsets.symmetric(horizontal: AppPadding.medium, vertical: AppPadding.small + AppPadding.tiny),
          child: IconTheme.merge(
            data: IconThemeData(size: dense ? 14 : 18, color: foreground),
            child: DefaultTextStyle.merge(style: labelStyle, child: child),
          ),
        ),
      ),
    );

    final margined = dense
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny, vertical: AppSpacing.small),
            child: pill,
          )
        : pill;
    return tooltip == null ? margined : Tooltip(message: tooltip, child: margined);
  }
}
