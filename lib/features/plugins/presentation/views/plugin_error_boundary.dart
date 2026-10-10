import 'package:flutter/material.dart';

class PluginErrorBoundary extends StatefulWidget {
  final String pluginName;
  final Widget child;

  const PluginErrorBoundary({
    super.key,
    required this.pluginName,
    required this.child,
  });

  @override
  State<PluginErrorBoundary> createState() => _PluginErrorBoundaryState();
}

class _PluginErrorBoundaryState extends State<PluginErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
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
                      'Este complemento se aisló para evitar interrumpir ZeeTools.\nPuede que el servicio no esté disponible o haya ocurrido un fallo temporal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      onPressed: () => setState(() => _error = null),
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
