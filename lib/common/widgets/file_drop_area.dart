import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Acepta archivos y carpetas soltados en cualquier punto de [child], con un
// recuadro que lo indica mientras se arrastra.
class FileDropArea extends StatefulWidget {
  const FileDropArea({super.key, required this.label, required this.onDrop, required this.child});

  final String label;
  final ValueChanged<List<String>> onDrop;
  final Widget child;

  @override
  State<FileDropArea> createState() => _FileDropAreaState();
}

class _FileDropAreaState extends State<FileDropArea> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) widget.onDrop(paths);
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    border: Border.all(color: cs.primary, width: 2),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Center(
                    child: Text(
                      widget.label,
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
