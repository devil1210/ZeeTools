import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Campo no controlado: el valor inicial solo se lee al construirse, por lo que
// el formulario que lo contiene se reconstruye con otra clave al cambiar de proyecto.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
    this.error,
    this.maxLines = 1,
    this.suffix,
    this.enabled = true,
    this.inputFormatters,
    this.floatLabel = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? helper;
  final String? error;
  final int maxLines;
  final Widget? suffix;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  // Mantiene la etiqueta arriba para que la sugerencia se vea sin enfocar el campo.
  final bool floatLabel;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      enabled: enabled,
      inputFormatters: inputFormatters,
      minLines: 1,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: floatLabel ? FloatingLabelBehavior.always : null,
        helperText: helper,
        helperMaxLines: 3,
        errorText: error,
        suffixIcon: suffix,
      ),
    );
  }
}
