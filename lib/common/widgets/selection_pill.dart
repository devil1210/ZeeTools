import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Opción conmutable con forma de rectángulo redondeado; la selección se indica
// solo con el color de fondo. `child` hereda el color vía [IconTheme]/
// [DefaultTextStyle]; para conservar uno propio, fijarlo en el hijo. `dense` la
// compacta para filas de herramientas.
class const SelectionPill({super.key, required final Widget child, required final bool selected, required final VoidCallback onTap, final Color? color, final bool dense = false, final String? tooltip}) extends StatelessWidget {
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
            child: DefaultTextStyle.merge(
              style: ((dense ? textTheme.labelSmall : textTheme.labelLarge) ?? const TextStyle()).copyWith(color: foreground, fontWeight: dense ? FontWeight.w600 : null),
              child: child,
            ),
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

// Opciones de un catálogo que pasan a la línea siguiente cuando no caben.
class const SelectionPillGroup<T>({
  super.key,
  required final Iterable<T> options,
  required final bool Function(T option) selected,
  required final ValueChanged<T> onTap,
  required final String Function(T option) label,
  final String? Function(T option)? tooltip,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final option in options)
          SelectionPill(
            selected: selected(option),
            tooltip: tooltip?.call(option),
            onTap: () => onTap(option),
            child: Text(label(option)),
          ),
      ],
    );
  }
}
