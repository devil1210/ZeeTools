import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Desplegable con el mismo borde, etiqueta y altura que los campos de texto.
// Sin [onChanged] queda deshabilitado.
class const OutlinedDropdown<T>({
  super.key,
  required final String label,
  required final T value,
  required final List<DropdownMenuItem<T>> items,
  required final ValueChanged<T?>? onChanged,
  final String? helper,
  final String? hint,
  final String? error,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppRadius.small),
      decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3, hintText: hint, errorText: error),
      items: items,
      onChanged: onChanged,
    );
  }
}
