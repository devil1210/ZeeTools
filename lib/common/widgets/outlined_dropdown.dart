import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Desplegable con el mismo borde, etiqueta y altura que los campos de texto.
// Sin [onChanged] queda deshabilitado.
class OutlinedDropdown<T> extends StatelessWidget {
  const OutlinedDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.helper, this.hint, this.floatLabel = false});

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? helper;
  final String? hint;
  // Mantiene la etiqueta arriba para que la sugerencia se vea sin abrir el desplegable.
  final bool floatLabel;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppRadius.small),
      decoration: InputDecoration(labelText: label, helperText: helper, hintText: hint, floatingLabelBehavior: floatLabel ? FloatingLabelBehavior.always : null),
      items: items,
      onChanged: onChanged,
    );
  }
}
