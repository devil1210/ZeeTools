import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Interruptor con el borde, la altura y el resaltado de un campo de texto, para
// alinearse con los campos que lo rodean.
class const ToggleField({super.key, required final String label, required final bool value, required final ValueChanged<bool>? onChanged, final String? helper}) extends StatefulWidget {
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
              Expanded(
                child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
              ),
              SizedBox(
                height: AppSize.medium - 2,
                child: FittedBox(
                  child: Switch(value: widget.value, onChanged: widget.onChanged),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
