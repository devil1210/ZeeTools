import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Sigue a [value]: lo escrito se notifica con onChanged y un valor que llega
// de fuera (datos importados o derivados) reemplaza el texto del campo.
class const AppTextField({
  super.key,
  required final String label,
  required final String value,
  required final ValueChanged<String> onChanged,
  final String? hint,
  final String? helper,
  final String? error,
  final int minLines = 1,
  final int maxLines = 1,
  final Widget? suffix,
  final bool enabled = true,
  final List<TextInputFormatter>? inputFormatters,
}) extends StatefulWidget {
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lo que el padre normaliza al escribir (p. ej. quitar espacios) no mueve el cursor.
    if (widget.value != _controller.text && widget.value != oldWidget.value && widget.value.trim() != _controller.text.trim()) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 3,
        errorText: widget.error,
        errorMaxLines: 2,
        suffixIcon: widget.suffix,
      ),
    );
  }
}
