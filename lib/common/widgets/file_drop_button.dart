import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

// Botón que abre el selector de archivos y además acepta soltar archivos sobre él;
// solo se entregan los que tienen alguna de las [extensions].
class FileDropButton extends StatefulWidget {
  const FileDropButton({
    super.key,
    required this.icon,
    required this.label,
    required this.extensions,
    required this.onPick,
    required this.onFiles,
    this.dropLabel = 'Suelta aquí los archivos',
  });

  final IconData icon;
  final String label;
  final List<String> extensions;
  final VoidCallback onPick;
  final ValueChanged<List<String>> onFiles;
  final String dropLabel;

  @override
  State<FileDropButton> createState() => _FileDropButtonState();
}

class _FileDropButtonState extends State<FileDropButton> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final files = [
          for (final f in details.files)
            if (widget.extensions.contains(p.extension(f.path).replaceFirst('.', '').toLowerCase())) f.path,
        ];
        if (files.isNotEmpty) widget.onFiles(files);
      },
      child: OutlinedButton.icon(
        style: _dragging
            ? OutlinedButton.styleFrom(
                backgroundColor: colors.primary.withValues(alpha: 0.08),
                side: BorderSide(color: colors.primary, width: 2),
              )
            : null,
        icon: Icon(_dragging ? Icons.file_download_outlined : widget.icon),
        label: Text(_dragging ? widget.dropLabel : widget.label),
        onPressed: widget.onPick,
      ),
    );
  }
}
