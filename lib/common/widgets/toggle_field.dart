import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Interruptor con el borde, la altura y el resaltado de un campo de texto, para
// alinearse con los campos que lo rodean.
class ToggleField extends StatefulWidget {
  const ToggleField({super.key, required this.label, required this.value, required this.onChanged, this.helper});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? helper;

  @override
  State<ToggleField> createState() => _ToggleFieldState();
}

class _ToggleFieldState extends State<ToggleField> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: InputDecorator(
          isHovering: _hovering && enabled,
          decoration: InputDecoration(
            enabled: enabled,
            helperText: widget.helper,
            helperMaxLines: 3,
            contentPadding: const EdgeInsets.only(left: AppPadding.medium + AppPadding.small, right: AppPadding.small),
          ),
          child: Row(
            children: [
              Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              SizedBox(
                height: AppSize.medium - 2,
                child: FittedBox(child: Switch(value: widget.value, onChanged: widget.onChanged)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
