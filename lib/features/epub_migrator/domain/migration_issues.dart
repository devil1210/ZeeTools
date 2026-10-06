import '/features/epub_templater/data/epub_template_builder.dart';
import '/features/epub_templater/domain/book_metadata.dart';
import '/features/epub_templater/domain/title_languages.dart';
import 'migration_kind.dart';
import 'migration_project.dart';

MigrationIssue _error(String message, [String? path]) => (level: MigrationIssueLevel.error, message: message, path: path);
MigrationIssue _warning(String message, [String? path]) => (level: MigrationIssueLevel.warning, message: message, path: path);
MigrationIssue _info(String message, [String? path]) => (level: MigrationIssueLevel.info, message: message, path: path);

// Lo que queda por resolver con lo editado hasta ahora; los errores impiden guardar.
List<MigrationIssue> migrationIssues(MigrationProject project) {
  final m = project.metadata;
  final titleLang = m.titleLang.trim().isEmpty ? m.language : m.titleLang.trim();
  final seriesLang = m.seriesLang.trim().isEmpty ? m.language : m.seriesLang.trim();
  final sections = project.docs.where((d) => !d.continuation).toList();
  final names = <String, int>{};
  for (final d in sections) {
    names.update(d.fileName.trim().toLowerCase(), (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    if (m.title.trim().isEmpty)
      _error('Falta el título en inglés.')
    else if (titleLang != mainTitleLanguage)
      _error('El título principal está en «$titleLang»: escríbelo en inglés.'),
    if (localizedText(m.altTitles, spanishLanguage).trim().isEmpty) _error('Falta el título en español.'),
    if (missingAlternates(m.altTitles).where((x) => x != 'en español').toList() case final missing when missing.isNotEmpty) _warning('Falta el título ${missing.join(', ')}.'),
    if (m.hasSeries && seriesLang != mainTitleLanguage) _warning('La serie principal está en «$seriesLang»: escríbela en inglés.'),
    if (m.hasSeries && missingAlternates(m.altSeries).isNotEmpty) _warning('Falta la serie ${missingAlternates(m.altSeries).join(', ')}.'),
    if (m.asin.trim().isEmpty) _warning('Sin ASIN de Amazon Japón.'),
    if (m.isbn13.trim().isNotEmpty && !isValidIsbn13(m.isbn13)) _warning('El ISBN-13 no es válido.'),
    if (m.isbn10.trim().isNotEmpty && !isValidIsbn10(m.isbn10)) _warning('El ISBN-10 no es válido.'),
    if (m.actors.any((a) => a.name.trim().isEmpty)) _warning('Hay personas sin nombre.'),
    if (m.publishers.every((x) => x.trim().isEmpty)) _warning('Sin editorial o grupo.'),
    if (m.description.trim().isEmpty) _info('Sin sinopsis.'),
    if (m.demographic == null || m.genres.isEmpty) _info('Sin demografía o géneros.'),
    if (project.docs.isEmpty) _error('El libro no tiene documentos en su orden de lectura.'),
    if (project.docs.firstOrNull?.continuation ?? false) _error('El primer documento no puede unirse a uno anterior.', project.docs.first.path),
    if (!project.docs.any((d) => d.kind == MigrationKind.cover)) _warning('No se reconoció la cubierta.'),
    for (final d in sections) ...[
      if (d.kind == MigrationKind.generic) _warning('«${d.label}» no tiene un tipo reconocible.', d.path),
      if (d.fileName.trim().isEmpty || sanitizeFileName(d.fileName) != d.fileName.trim()) _error('«${d.fileName}» no es un nombre de archivo válido.', d.path),
      if ((names[d.fileName.trim().toLowerCase()] ?? 0) > 1) _error('El archivo «${d.fileName}» está repetido.', d.path),
    ],
    if (project.unknownClasses.isNotEmpty) _warning('Clases sin equivalente ni regla propia: ${project.unknownClasses.join(', ')}.'),
    ...project.readIssues,
    for (final d in project.docs)
      for (final note in d.notes) _info(note, d.path),
  ];
}
