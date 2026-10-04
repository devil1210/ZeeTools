import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Opción conmutable en forma de rectángulo redondeado; la selección se indica
// solo con el color de fondo.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pill = Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppPadding.medium, vertical: AppPadding.small + AppPadding.tiny),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant),
          ),
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}

// Etiqueta fija con el mismo aspecto que [ChoicePill], opcionalmente quitable.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.label, this.onRemove, this.tooltip});

  final String label;
  final VoidCallback? onRemove;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pill = Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: EdgeInsets.only(left: AppPadding.medium, right: onRemove == null ? AppPadding.medium : AppPadding.tiny),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppPadding.small + AppPadding.tiny),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSecondaryContainer)),
            ),
            if (onRemove case final remove?)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.small),
                onTap: remove,
                child: Padding(
                  padding: const EdgeInsets.all(AppPadding.small),
                  child: Icon(Icons.close, size: 16, color: colors.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}
