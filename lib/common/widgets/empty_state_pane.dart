import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import 'toggle_field.dart';

typedef PaneAction = ({IconData icon, String label, VoidCallback onPressed});

// Estado inicial de una herramienta sin archivos abiertos: qué hacer, cómo abrir
// archivos o carpetas y si las carpetas incluyen sus subcarpetas.
class EmptyStatePane extends StatelessWidget {
  const EmptyStatePane({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.primary,
    this.secondary,
    required this.recursive,
    required this.recursiveLabel,
    required this.onRecursiveChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final PaneAction primary;
  final PaneAction? secondary;
  final bool recursive;
  final String recursiveLabel;
  final ValueChanged<bool> onRecursiveChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppPadding.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.medium + AppSpacing.small,
            children: [
              Icon(icon, size: 64, color: cs.outline),
              Text(title, textAlign: TextAlign.center),
              if (subtitle case final text?)
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
              const SizedBox(height: AppSpacing.small),
              Row(
                spacing: AppSpacing.medium,
                children: [
                  Expanded(
                    child: FilledButton.icon(icon: Icon(primary.icon), label: Text(primary.label), onPressed: primary.onPressed),
                  ),
                  if (secondary case final action?)
                    Expanded(
                      child: OutlinedButton.icon(icon: Icon(action.icon), label: Text(action.label), onPressed: action.onPressed),
                    ),
                ],
              ),
              ToggleField(label: recursiveLabel, value: recursive, onChanged: onRecursiveChanged),
            ],
          ),
        ),
      ),
    );
  }
}
