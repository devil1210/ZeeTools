import 'package:freezed_annotation/freezed_annotation.dart';

part 'embedded_font.freezed.dart';
part 'embedded_font.g.dart';

enum GenericFamily { serif, sansSerif, cursive, fantasy, monospace }

extension GenericFamilyX on GenericFamily {
  String get css => switch (this) {
    GenericFamily.sansSerif => 'sans-serif',
    _ => name,
  };
}

@Freezed()
abstract class EmbeddedFont with _$EmbeddedFont {
  const factory EmbeddedFont({
    @Default('') String family,
    // Vacío = se buscan en el sistema las variantes de [family] al generar.
    @Default([]) List<String> files,
    @Default(GenericFamily.serif) GenericFamily fallback,
    // Niveles de título (1–9) que usan la fuente.
    @Default([]) List<int> headingLevels,
  }) = _EmbeddedFont;

  factory EmbeddedFont.fromJson(Map<String, dynamic> json) => _$EmbeddedFontFromJson(json);
}

extension EmbeddedFontX on EmbeddedFont {
  // Clase que se genera siempre para aplicar la fuente a mano, p. ej. en un párrafo.
  String get cssClass {
    final slug = family.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return 'font-${slug.isEmpty ? 'custom' : slug}';
  }
}
