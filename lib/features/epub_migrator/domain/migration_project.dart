import 'package:freezed_annotation/freezed_annotation.dart';

import '/features/epub_templater/domain/book_metadata.dart';
import '/features/epub_templater/domain/content_warning.dart';
import '/features/epub_templater/domain/section_kind.dart';
import 'migration_kind.dart';

part 'migration_project.freezed.dart';

// Un documento del spine y lo que será en el libro migrado.
@Freezed(makeCollectionsUnmodifiable: false)
abstract class MigrationDoc with _$MigrationDoc {
  const factory MigrationDoc({
    // Ruta dentro del EPUB original.
    required String path,
    required MigrationKind kind,
    required BookMatter matter,
    // Entrada del índice y <title> del documento.
    required String label,
    required bool inToc,
    // Se une al documento anterior con un salto de página.
    @Default(false) bool continuation,
    // Nombre sin extensión en el libro migrado.
    required String fileName,
    // Por qué se clasificó así o qué conviene revisar.
    @Default([]) List<String> notes,
    @Default('') String oldType,
    @Default('') String headingText,
    @Default(0) int paragraphs,
    @Default(0) int images,
    // El XHTML no es XML bien formado: se copia sin migrar.
    @Default(false) bool broken,
  }) = _MigrationDoc;
}

enum MigrationIssueLevel { error, warning, info }

typedef MigrationIssue = ({MigrationIssueLevel level, String message, String? path});

@Freezed(makeCollectionsUnmodifiable: false)
abstract class MigrationProject with _$MigrationProject {
  const factory MigrationProject({
    required String sourcePath,
    required BookMetadata metadata,
    required List<MigrationDoc> docs,
    // Clase antigua → clases del template.
    @Default({}) Map<String, List<String>> classRenames,
    // Clases usadas en el libro que el template no define ni tienen regla propia.
    @Default([]) List<String> unknownClasses,
    // Reglas propias del libro que se conservan al final de style.css.
    @Default('') String customCss,
    // Hojas del libro que sustituyen style.css y nav-style.css del template.
    @Default([]) List<String> replacedSheets,
    // Tipo de la advertencia; su texto se reescribe con el estándar.
    @Default(ContentWarning.explicit) ContentWarning warning,
    // Añadir una advertencia cuando el libro no la tiene.
    @Default(false) bool addNotice,
    // Añadir logos.xhtml con el logo de ZeePubs cuando el libro no tiene página de logos.
    @Default(true) bool addLogos,
    // Problemas detectados al leer el libro que no dependen de lo que se edite.
    @Default([]) List<MigrationIssue> readIssues,
  }) = _MigrationProject;
}
