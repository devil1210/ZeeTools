import 'package:flutter/material.dart';

/// Wraps [child] in an error-catching boundary.
///
/// If [child] throws an unhandled exception during its build phase, the
/// boundary swallows the error and renders a recovery screen instead.
/// ZeeTools continues operating normally regardless of the plugin's state.
///
/// Tapping **Reintentar** resets the boundary and attempts to render
/// [child] again.
///
/// ## Usage
///
/// ```dart
/// PluginErrorBoundary(
///   pluginName: manifest.name,
///   child: MyPluginView(),
/// )
/// ```
class PluginErrorBoundary extends StatefulWidget {
  /// The display name of the plugin, shown in the recovery screen app bar.
  final String pluginName;

  /// The plugin widget subtree to protect.
  final Widget child;

  const PluginErrorBoundary({
    super.key,
    required this.pluginName,
    required this.child,
  });

  @override
  State<PluginErrorBoundary> createState() => PluginErrorBoundaryState();
}

/// Exposed for testing: allows [simulateError] to trigger the error screen.
@visibleForTesting
class PluginErrorBoundaryState extends State<PluginErrorBoundary> {
  Object? error;

  /// Forces the boundary into its error state.
  ///
  /// Use only in widget tests to verify the recovery screen behaviour.
  @visibleForTesting
  void simulateError(Object err) => setState(() => error = err);

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text(widget.pluginName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: cs.errorContainer.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Problema en el complemento "${widget.pluginName}"',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este complemento se aisló para evitar interrumpir ZeeTools.\n'
                      'Puede que el servicio no esté disponible o haya ocurrido un fallo temporal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      onPressed: () => setState(() => error = null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
