import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/common/theme/app_dimensions.dart';

const languageSuggestions = {
  'es': 'Español',
  'en': 'Inglés',
  'ja': 'Japonés',
  'ja-Latn': 'Japonés en romaji',
  'zh': 'Chino',
  'ko': 'Coreano',
};

// Campo no controlado: el valor inicial solo se lee al construirse, por lo que
// el formulario que lo contiene se reconstruye con otra clave al cambiar de proyecto.
class TemplateTextField extends StatelessWidget {
  const TemplateTextField({
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
        helperText: helper,
        helperMaxLines: 3,
        errorText: error,
        suffixIcon: suffix,
      ),
    );
  }
}

// Etiqueta de idioma BCP 47 con sugerencias; admite cualquier otra escrita a mano.
class LanguageField extends StatefulWidget {
  const LanguageField({super.key, required this.label, required this.value, required this.onChanged, this.error, this.enabled = true});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool enabled;

  @override
  State<LanguageField> createState() => _LanguageFieldState();
}

class _LanguageFieldState extends State<LanguageField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.error,
        suffixIcon: PopupMenuButton<String>(
          enabled: widget.enabled,
          tooltip: 'Idiomas frecuentes',
          icon: const Icon(Icons.translate, size: 18),
          onSelected: (lang) {
            _controller.text = lang;
            widget.onChanged(lang);
          },
          itemBuilder: (_) => [
            for (final MapEntry(key: code, value: name) in languageSuggestions.entries) PopupMenuItem(value: code, child: Text('$name ($code)')),
          ],
        ),
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium + AppPadding.small, AppPadding.large, AppPadding.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

// Una columna por defecto; a partir de [breakpoint] los campos van en fila.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({super.key, required this.children, this.flex, this.widths, this.breakpoint = 900});

  final List<Widget> children;
  final List<int>? flex;
  // Ancho fijo por columna en fila; null reparte el resto según [flex].
  final List<double?>? widths;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpacing.medium + AppSpacing.small, children: children);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
          children: [
            for (final (i, child) in children.indexed)
              if (widths?[i] case final width?) SizedBox(width: width, child: child) else Expanded(flex: flex?[i] ?? 1, child: child),
          ],
        );
      },
    );
  }
}

// Desplegable con el mismo borde, etiqueta y altura que los campos de texto.
class OutlinedDropdown<T> extends StatelessWidget {
  const OutlinedDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.helper});

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppRadius.small),
      decoration: InputDecoration(labelText: label, helperText: helper),
      items: items,
      onChanged: onChanged,
    );
  }
}

const languageColumnWidth = 200.0;
const numberColumnWidth = 120.0;

// Números con decimales opcionales, p. ej. 3 o 3.5.
final decimalNumberFormatter = TextInputFormatter.withFunction((oldValue, newValue) => RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text) ? newValue : oldValue);
