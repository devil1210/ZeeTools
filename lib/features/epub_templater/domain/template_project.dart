import 'package:freezed_annotation/freezed_annotation.dart';

import 'book_metadata.dart';
import 'embedded_font.dart';
import 'section_kind.dart';
import 'template_section.dart';

part 'template_project.freezed.dart';
part 'template_project.g.dart';

@Freezed()
abstract class TemplateProject with _$TemplateProject {
  const factory TemplateProject({
    @Default([]) List<TemplateSection> sections,
    @Default(BookMetadata()) BookMetadata metadata,
    @Default([]) List<EmbeddedFont> fonts,
    // Comentarios que orientan al maquetador en el XHTML y en la hoja de estilos.
    @Default(false) bool guideComments,
  }) = _TemplateProject;

  factory TemplateProject.fromJson(Map<String, dynamic> json) => _$TemplateProjectFromJson(json);

  factory TemplateProject.initial() => TemplateProject(
    metadata: BookMetadata.initial(),
    fonts: const [
      EmbeddedFont(family: 'Times New Roman', headingLevels: [1]),
    ],
    sections: [
      for (final kind in const [
        SectionKind.cover,
        SectionKind.synopsis,
        SectionKind.illustrations,
        SectionKind.authorProfile,
        SectionKind.titlePage,
        SectionKind.colophon,
        SectionKind.contentsImage,
        SectionKind.epigraph,
        SectionKind.preface,
        SectionKind.prologue,
      ])
        TemplateSection.of(kind),
      TemplateSection.of(SectionKind.chapter),
      TemplateSection.of(SectionKind.chapter, number: 2),
      for (final kind in const [
        SectionKind.epilogue,
        SectionKind.afterword,
        SectionKind.translatorNotes,
        SectionKind.backCover,
        SectionKind.endnotes,
      ])
        TemplateSection.of(kind),
    ],
  );

  // Una sección de cada tipo, en el orden de sus divisiones.
  factory TemplateProject.allSections() => TemplateProject.initial().copyWith(
    sections: [
      for (final matter in BookMatter.values)
        for (final kind in SectionKind.values.where((k) => k.matter == matter)) TemplateSection.of(kind),
    ],
  );
}
