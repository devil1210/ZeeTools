import 'package:freezed_annotation/freezed_annotation.dart';

import '/common/utils/uuid_v7.dart';
import 'section_kind.dart';

part 'template_section.freezed.dart';
part 'template_section.g.dart';

@Freezed()
abstract class TemplateSection with _$TemplateSection {
  const factory TemplateSection({
    required String key,
    required SectionKind kind,
    required String fileName,
    required String title,
    @Default('') String subtitle,
    // Vacío = título y subtítulo unidos por dos puntos.
    @Default('') String tocLabel,
    @Default(true) bool inToc,
    @Default(false) bool hideHeading,
    // Nivel en el índice y del encabezado (h1–h6).
    @Default(1) int level,
    required String epubType,
    required BookMatter matter,
    // Vacío = aria-labelledby apuntando al encabezado.
    @Default('') String ariaLabel,
    @Default([]) List<String> images,
    @Default(true) bool zeepubsLogo,
    @Default(HeadingStyle.text) HeadingStyle headingStyle,
    @Default('') String headingImage,
  }) = _TemplateSection;

  factory TemplateSection.fromJson(Map<String, dynamic> json) => _$TemplateSectionFromJson(json);

  // [number] solo aplica a los tipos numerados. La página de título se crea sin
  // título para que muestre el del libro.
  factory TemplateSection.of(SectionKind kind, {int number = 1}) => TemplateSection(
    key: uuidV7(),
    kind: kind,
    fileName: kind.numbered ? '${kind.fileName}${number.toString().padLeft(2, '0')}' : kind.fileName,
    title: switch (kind) {
      _ when kind.numbered => '${kind.title} $number',
      SectionKind.titlePage => '',
      _ => kind.title,
    },
    inToc: kind.inToc,
    hideHeading: kind.hideHeading,
    epubType: kind.epubType,
    matter: kind.matter,
  );
}

extension TemplateSectionX on TemplateSection {
  String get effectiveTocLabel {
    if (tocLabel.trim().isNotEmpty) return tocLabel.trim();
    // Sin título propio, la página de título muestra el del libro, que no sirve como entrada del índice.
    if (kind.layout == SectionLayout.titlePage && title.trim().isEmpty) return kind.title;
    return subtitle.trim().isEmpty ? title.trim() : '${title.trim()}: ${subtitle.trim()}';
  }

  String get href => '$fileName.xhtml';

  String get role => epubTypeRoles[epubType] ?? '';
}
