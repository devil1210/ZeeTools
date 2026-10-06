import 'book_metadata.dart';

// Título y serie van en inglés, salvo en las obras escritas en español; sus
// equivalentes, en el idioma del libro, en español y en el idioma original,
// romanizado y en su escritura.
const mainTitleLanguage = 'en';
const spanishLanguage = 'es';

// Idioma en que se escribió la obra. Los de escritura propia ([romanization])
// añaden los equivalentes romanizado y en su escritura.
enum OriginalLanguage {
  ja('Japonés', 'romaji'),
  ko('Coreano', 'romanización'),
  zh('Chino', 'pinyin'),
  en('Inglés', null),
  es('Español', null);

  const OriginalLanguage(this.label, this.romanization);

  final String label;
  final String? romanization;

  bool get scripted => romanization != null;

  String get romanized => '$name-Latn';

  // Idioma del título y la serie principales.
  String get mainLanguage => this == es ? spanishLanguage : mainTitleLanguage;
}

const scriptedLanguages = [OriginalLanguage.ja, OriginalLanguage.ko, OriginalLanguage.zh];

String _key(String lang) => lang.trim().toLowerCase();

OriginalLanguage? _originalOf(String lang) => scriptedLanguages.where((o) => o.name == _key(lang).split('-').first).firstOrNull;

OriginalLanguage? originalLanguageNamed(String lang) => OriginalLanguage.values.where((o) => o.name == _key(lang).split('-').first).firstOrNull;

String localizedText(List<LocalizedText> items, String lang) => items.where((t) => _key(t.lang) == _key(lang)).firstOrNull?.text ?? '';

OriginalLanguage? originalLanguageOf(List<LocalizedText> items) => items.map((t) => _originalOf(t.lang)).nonNulls.firstOrNull;

// Orden de los equivalentes: español, inglés, romanizado, escritura original y el resto.
List<LocalizedText> _ordered(List<LocalizedText> items) {
  int rank(LocalizedText t) => switch (_key(t.lang)) {
    spanishLanguage => 0,
    mainTitleLanguage => 1,
    final lang when _originalOf(lang) != null => lang.endsWith('-latn') ? 2 : 3,
    _ => 4,
  };
  return [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
}

List<LocalizedText> withLocalizedText(List<LocalizedText> items, String lang, String text) {
  final i = items.indexWhere((t) => _key(t.lang) == _key(lang));
  return _ordered(i < 0 ? [...items, LocalizedText(lang: lang, text: text)] : ([...items]..[i] = items[i].copyWith(text: text)));
}

// Cambia el idioma de los equivalentes en el idioma original (o los crea) sin tocar su texto.
List<LocalizedText> withOriginalLanguage(List<LocalizedText> items, OriginalLanguage? lang) {
  final scripted = lang != null && lang.scripted ? lang : null;
  final kept = [
    for (final t in items)
      if (_originalOf(t.lang) == null) t else if (scripted != null) t.copyWith(lang: _key(t.lang).endsWith('-latn') ? scripted.romanized : scripted.name),
  ];
  if (scripted == null) return kept;
  return _ordered([
    ...kept,
    if (!kept.any((t) => t.lang == scripted.romanized)) LocalizedText(lang: scripted.romanized),
    if (!kept.any((t) => t.lang == scripted.name)) LocalizedText(lang: scripted.name),
  ]);
}

typedef MainText = ({String text, String lang, List<LocalizedText> alternates});

// Si el principal no está en [main] pero hay un equivalente que sí, se intercambian.
MainText mainFirst(String text, String lang, List<LocalizedText> alternates, {String main = mainTitleLanguage}) {
  final i = alternates.indexWhere((t) => _key(t.lang) == _key(main) && t.text.trim().isNotEmpty);
  if (_key(lang) == _key(main) || i < 0) return (text: text, lang: lang, alternates: alternates);
  final rest = [...alternates]..removeAt(i);
  return (
    text: alternates[i].text,
    lang: main,
    alternates: _ordered([if (text.trim().isNotEmpty && lang.isNotEmpty) LocalizedText(lang: lang, text: text), ...rest]),
  );
}

// [main] pasa a ser el idioma principal: su equivalente sube a principal (vacío si no lo hay) y el
// principal actual queda como equivalente.
MainText withMainLanguage(String text, String lang, List<LocalizedText> alternates, String main) {
  if (_key(lang) == _key(main)) return (text: text, lang: lang, alternates: alternates);
  return (
    text: localizedText(alternates, main),
    lang: main,
    alternates: _ordered([
      if (text.trim().isNotEmpty && lang.trim().isNotEmpty) LocalizedText(lang: lang, text: text),
      ...alternates.where((t) => _key(t.lang) != _key(main)),
    ]),
  );
}

const _languageNames = {'es': 'español', 'en': 'inglés', 'ja': 'japonés', 'ko': 'coreano', 'zh': 'chino', 'fr': 'francés', 'pt': 'portugués', 'it': 'italiano', 'de': 'alemán'};

// Nombre en minúscula para las etiquetas («Título en japonés»); el código si no se conoce.
String languageName(String code) => _languageNames[_key(code).split('-').first] ?? code.trim();

// El idioma del libro, si no es el del principal, es el equivalente obligatorio del título y la serie.
String? requiredAlternate(String bookLanguage, {String main = mainTitleLanguage}) {
  final base = _key(bookLanguage).split('-').first;
  return base.isEmpty || base == _key(main) ? null : base;
}

// Falta el equivalente en el idioma del libro.
bool missingRequired(List<LocalizedText> items, String bookLanguage, {String main = mainTitleLanguage}) => switch (requiredAlternate(bookLanguage, main: main)) {
  final lang? => localizedText(items, lang).trim().isEmpty,
  null => false,
};
