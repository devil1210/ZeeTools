import 'package:flutter/material.dart';

const languageSuggestions = {
  'es': 'Español',
  'en': 'Inglés',
  'ja': 'Japonés',
  'ja-Latn': 'Japonés en romaji',
  'zh': 'Chino',
  'ko': 'Coreano',
};

// Idiomas en que se publica un libro.
const bookLanguages = {
  'es': 'Español',
  'en': 'Inglés',
  'ja': 'Japonés',
  'zh': 'Chino',
  'ko': 'Coreano',
};

// Etiqueta de idioma BCP 47 con sugerencias; admite cualquier otra escrita a mano.
class LanguageField extends StatefulWidget {
  const LanguageField({super.key, required this.label, required this.value, required this.onChanged, this.error, this.hint, this.floatLabel = false, this.enabled = true});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String? hint;
  final bool floatLabel;
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
        hintText: widget.hint,
        floatingLabelBehavior: widget.floatLabel ? FloatingLabelBehavior.always : null,
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

const languageColumnWidth = 200.0;
const numberColumnWidth = 120.0;
