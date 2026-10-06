import 'book_metadata.dart';

// Título y serie van en inglés; sus equivalentes, en español y en el idioma
// original, romanizado y en su escritura.
const mainTitleLanguage = 'en';
const spanishLanguage = 'es';

enum OriginalLanguage {
  ja('Japonés', 'romaji'),
  ko('Coreano', 'romanización'),
  zh('Chino', 'pinyin');

  const OriginalLanguage(this.label, this.romanization);

  final String label;
  final String romanization;

  String get romanized => '$name-Latn';
}

String _key(String lang) => lang.trim().toLowerCase();

OriginalLanguage? _originalOf(String lang) => OriginalLanguage.values.where((o) => o.name == _key(lang).split('-').first).firstOrNull;

String localizedText(List<LocalizedText> items, String lang) => items.where((t) => _key(t.lang) == _key(lang)).firstOrNull?.text ?? '';

OriginalLanguage? originalLanguageOf(List<LocalizedText> items) => items.map((t) => _originalOf(t.lang)).nonNulls.firstOrNull;

// Orden de los equivalentes: español, romanizado, escritura original y el resto.
List<LocalizedText> _ordered(List<LocalizedText> items) {
  int rank(LocalizedText t) => switch (_key(t.lang)) {
    spanishLanguage => 0,
    final lang when _originalOf(lang) != null => lang.endsWith('-latn') ? 1 : 2,
    _ => 3,
  };
  return [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
}

List<LocalizedText> withLocalizedText(List<LocalizedText> items, String lang, String text) {
  final i = items.indexWhere((t) => _key(t.lang) == _key(lang));
  return _ordered(i < 0 ? [...items, LocalizedText(lang: lang, text: text)] : ([...items]..[i] = items[i].copyWith(text: text)));
}

// Cambia el idioma de los equivalentes en el idioma original (o los crea) sin tocar su texto.
List<LocalizedText> withOriginalLanguage(List<LocalizedText> items, OriginalLanguage? lang) {
  final kept = [
    for (final t in items)
      if (_originalOf(t.lang) == null)
        t
      else if (lang != null)
        t.copyWith(lang: _key(t.lang).endsWith('-latn') ? lang.romanized : lang.name),
  ];
  if (lang == null) return kept;
  return _ordered([
    ...kept,
    if (!kept.any((t) => t.lang == lang.romanized)) LocalizedText(lang: lang.romanized),
    if (!kept.any((t) => t.lang == lang.name)) LocalizedText(lang: lang.name),
  ]);
}

// Si el principal no está en inglés pero hay un equivalente que sí, se intercambian.
({String text, String lang, List<LocalizedText> alternates}) englishFirst(String text, String lang, List<LocalizedText> alternates) {
  final i = alternates.indexWhere((t) => _key(t.lang) == mainTitleLanguage && t.text.trim().isNotEmpty);
  if (_key(lang) == mainTitleLanguage || i < 0) return (text: text, lang: lang, alternates: alternates);
  final rest = [...alternates]..removeAt(i);
  return (
    text: alternates[i].text,
    lang: mainTitleLanguage,
    alternates: _ordered([if (text.trim().isNotEmpty && lang.isNotEmpty) LocalizedText(lang: lang, text: text), ...rest]),
  );
}

const _languageNames = {'es': 'español', 'en': 'inglés', 'ja': 'japonés', 'ko': 'coreano', 'zh': 'chino', 'fr': 'francés', 'pt': 'portugués', 'it': 'italiano', 'de': 'alemán'};

// Nombre en minúscula para las etiquetas («Título en japonés»); el código si no se conoce.
String languageName(String code) => _languageNames[_key(code).split('-').first] ?? code.trim();

// El idioma del libro, salvo el inglés del principal, es el equivalente obligatorio del título.
String? requiredAlternate(String bookLanguage) {
  final base = _key(bookLanguage).split('-').first;
  return base.isEmpty || base == mainTitleLanguage ? null : base;
}

// Falta el equivalente en el idioma del libro.
bool missingRequired(List<LocalizedText> items, String bookLanguage) => switch (requiredAlternate(bookLanguage)) {
  final lang? => localizedText(items, lang).trim().isEmpty,
  null => false,
};
