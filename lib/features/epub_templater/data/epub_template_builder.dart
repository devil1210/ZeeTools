import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/book_metadata.dart';
import '../domain/embedded_font.dart';
import '../domain/marc_relator.dart';
import '../domain/section_kind.dart';
import '../domain/template_project.dart';
import '../domain/template_section.dart';
import '../domain/title_languages.dart';
import 'opf_metadata.dart';
import 'system_fonts.dart';

typedef EpubEntry = ({String path, Uint8List bytes});

typedef FontFile = ({String path, Uint8List bytes, int weight, bool italic});

typedef ResolvedFont = ({EmbeddedFont font, List<FontFile> files});

const navFileName = 'toc.xhtml';
const zeepubsLogoName = 'zeepubs.png';

const _imageMediaTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'jxl': 'image/jxl',
  'svg': 'image/svg+xml',
};

const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'jxl', 'svg'];

// Tipos que no se repiten como punto de referencia: el cuerpo ya se marca con
// bodymatter en su primera sección.
const _nonLandmarkTypes = {'chapter', 'part', 'notice', 'colophon', 'abstract'};

final _isbn13 = RegExp(r'^97[89]\d{10}$');
final _isbn10 = RegExp(r'^\d{9}[\dX]$');

String _digits(String isbn) => isbn.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

bool isValidIsbn13(String isbn) {
  final d = _digits(isbn);
  if (!_isbn13.hasMatch(d)) return false;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(d[i]) * (i.isEven ? 1 : 3);
  }
  return sum % 10 == 0;
}

bool isValidIsbn10(String isbn) {
  final d = _digits(isbn);
  if (!_isbn10.hasMatch(d)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    sum += (d[i] == 'X' ? 10 : int.parse(d[i])) * (10 - i);
  }
  return sum % 11 == 0;
}

// Solo los ISBN-13 con prefijo 978 tienen equivalente de 10 dígitos.
String? isbn10From13(String isbn) {
  final d = _digits(isbn);
  if (!isValidIsbn13(d) || !d.startsWith('978')) return null;
  final core = d.substring(3, 12);
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += int.parse(core[i]) * (10 - i);
  }
  final check = (11 - sum % 11) % 11;
  return '$core${check == 10 ? 'X' : check}';
}

String? isbn13From10(String isbn) {
  final d = _digits(isbn);
  if (!isValidIsbn10(d)) return null;
  final core = '978${d.substring(0, 9)}';
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(core[i]) * (i.isEven ? 1 : 3);
  }
  return '$core${(10 - sum % 10) % 10}';
}

String sanitizeFileName(String name) => name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

enum IssueLevel { error, warning }

// Los problemas de metadatos se muestran en su propio campo; el resto en un aviso general.
enum IssueScope { metadata, sections, fonts }

typedef TemplateIssue = ({IssueLevel level, IssueScope scope, String message});

List<TemplateIssue> templateIssues(TemplateProject project) {
  final m = project.metadata;
  final issues = <TemplateIssue>[];
  void add(IssueLevel level, IssueScope scope, String message) => issues.add((level: level, scope: scope, message: message));

  if (m.title.trim().isEmpty) add(IssueLevel.error, IssueScope.metadata, 'El título es obligatorio.');
  if (m.title.trim().isNotEmpty && localizedText(m.altTitles, spanishLanguage).trim().isEmpty) add(IssueLevel.error, IssueScope.metadata, 'El título en español es obligatorio.');
  if (missingAlternates(m.altTitles).where((x) => x != 'en español').toList() case final missing when missing.isNotEmpty) add(IssueLevel.warning, IssueScope.metadata, 'Falta el título ${missing.join(', ')}.');
  if (m.hasSeries && missingAlternates(m.altSeries).isNotEmpty) add(IssueLevel.warning, IssueScope.metadata, 'Falta la serie ${missingAlternates(m.altSeries).join(', ')}.');
  if (m.language.trim().isEmpty) add(IssueLevel.error, IssueScope.metadata, 'El idioma es obligatorio.');
  if (m.isbn13.trim().isNotEmpty && !isValidIsbn13(m.isbn13)) add(IssueLevel.warning, IssueScope.metadata, 'El ISBN-13 no es válido.');
  if (m.isbn10.trim().isNotEmpty && !isValidIsbn10(m.isbn10)) add(IssueLevel.warning, IssueScope.metadata, 'El ISBN-10 no es válido.');
  if (m.hasSeries && double.tryParse(m.seriesIndex.trim()) == null) add(IssueLevel.warning, IssueScope.metadata, 'El número de volumen no es numérico.');
  if (m.date.trim().isNotEmpty && DateTime.tryParse(m.date.trim()) == null) add(IssueLevel.error, IssueScope.metadata, 'La fecha no tiene formato AAAA-MM-DD.');

  if (project.sections.isEmpty) add(IssueLevel.error, IssueScope.sections, 'La plantilla no tiene secciones.');
  final seen = <String>{};
  for (final s in project.sections) {
    final name = sanitizeFileName(s.fileName).toLowerCase();
    if (name.isEmpty) add(IssueLevel.error, IssueScope.sections, 'Una sección «${s.kind.label}» no tiene nombre de archivo.');
    if (name == p.withoutExtension(navFileName)) add(IssueLevel.error, IssueScope.sections, '«${s.fileName}» está reservado para el índice.');
    if (!seen.add(name)) add(IssueLevel.error, IssueScope.sections, 'El archivo «${s.fileName}» está repetido.');
    if (s.kind.layout != SectionLayout.titlePage && s.title.trim().isEmpty) add(IssueLevel.error, IssueScope.sections, 'La sección «${s.fileName}» no tiene título.');
    if (s.kind.layout == SectionLayout.text && s.headingStyle.usesImage && s.headingImage.isEmpty) add(IssueLevel.warning, IssueScope.sections, '«${s.fileName}» usa «${s.headingStyle.label}» sin imagen.');
  }
  if (project.sections.where((s) => s.kind == SectionKind.cover).length > 1) add(IssueLevel.error, IssueScope.sections, 'Solo puede haber una cubierta.');

  for (final f in project.fonts) {
    if (f.family.trim().isEmpty && f.files.isEmpty) add(IssueLevel.error, IssueScope.fonts, 'Hay una fuente sin elegir.');
  }
  return issues;
}

// Genera el contenido de un EPUB 3.4 a partir de la plantilla. [images] contiene
// los bytes de cada ruta de imagen referida por las secciones.
class EpubTemplateBuilder {
  EpubTemplateBuilder({
    required this.project,
    required this.styleCss,
    required this.navCss,
    required this.images,
    this.extensionOverrides = const {},
    this.zeepubsLogo,
    this.fonts = const [],
    DateTime? now,
  }) : now = (now ?? DateTime.now()).toUtc();

  final TemplateProject project;
  final String styleCss;
  final String navCss;
  final Map<String, Uint8List> images;
  // Extensión de la imagen cuando sus bytes no son del formato de la ruta de origen.
  final Map<String, String> extensionOverrides;
  final Uint8List? zeepubsLogo;
  final List<ResolvedFont> fonts;
  final DateTime now;

  BookMetadata get _meta => project.metadata;

  String get _lang => _meta.language.trim();

  // Ruta de origen → nombre dentro de Images/ o Fonts/.
  final _imageNames = <String, String>{};
  final _fontNames = <String, String>{};
  final _sectionFiles = <TemplateSection, List<String>>{};

  List<EpubEntry> build() {
    _assignFileNames();
    _assignImageNames();
    _assignFontNames();

    final entries = <EpubEntry>[
      _text('mimetype', 'application/epub+zip'),
      _text('META-INF/container.xml', _containerXml),
      _text('META-INF/com.apple.ibooks.display-options.xml', _appleOptionsXml),
      _text('OEBPS/content.opf', _opf()),
      _text('OEBPS/Styles/style.css', '${project.guideComments ? styleCss : _withoutGuideComments(styleCss)}${_fontCss()}${_customCss()}'),
      _text('OEBPS/Styles/nav-style.css', navCss),
      _text('OEBPS/Text/$navFileName', _nav()),
    ];
    for (final section in project.sections) {
      for (final (i, file) in _sectionFiles[section]!.indexed) {
        entries.add(_text('OEBPS/Text/$file', _sectionXhtml(section, i)));
      }
    }
    for (final MapEntry(key: source, value: name) in _imageNames.entries) {
      final bytes = source == zeepubsLogoName ? zeepubsLogo : images[source];
      if (bytes != null) entries.add((path: 'OEBPS/Images/$name', bytes: bytes));
    }
    for (final file in fonts.expand((f) => f.files)) {
      entries.add((path: 'OEBPS/Fonts/${_fontNames[file.path]}', bytes: file.bytes));
    }
    return entries;
  }

  EpubEntry _text(String path, String content) => (path: path, bytes: Uint8List.fromList(utf8.encode(content)));

  // ── Recursos ────────────────────────────────────────────────────────────────

  void _assignFileNames() {
    final used = <String>{p.withoutExtension(navFileName)};
    String unique(String base) {
      var name = base.isEmpty ? 'seccion' : base;
      for (var n = 2; !used.add(name.toLowerCase()); n++) {
        name = '${base}_$n';
      }
      return name;
    }

    for (final section in project.sections) {
      final base = unique(sanitizeFileName(section.fileName));
      // Una página por imagen; la página separadora antecede a la del texto.
      final pages = switch (section.kind.layout) {
        SectionLayout.images => section.images.length.clamp(1, 9999),
        SectionLayout.text when section.headingStyle == HeadingStyle.separatorPage => 2,
        _ => 1,
      };
      _sectionFiles[section] = [
        for (var i = 0; i < pages; i++) i == 0 ? '$base.xhtml' : '${unique('${base}_${i.toString().padLeft(4, '0')}')}.xhtml',
      ];
    }
  }

  void _assignImageNames() {
    final used = <String>{};
    String unique(String stem, String ext) {
      var name = '$stem.$ext';
      for (var n = 2; !used.add(name.toLowerCase()); n++) {
        name = '${stem}_$n.$ext';
      }
      return name;
    }

    for (final section in project.sections) {
      for (final source in [...section.images, ?_headingImageOf(section)]) {
        if (_imageNames.containsKey(source) || !images.containsKey(source)) continue;
        final ext = extensionOverrides[source] ?? p.extension(source).replaceFirst('.', '').toLowerCase();
        if (!_imageMediaTypes.containsKey(ext)) continue;
        final stem = section.kind == SectionKind.cover ? 'cover' : sanitizeFileName(p.basenameWithoutExtension(source));
        _imageNames[source] = unique(stem, ext == 'jpeg' ? 'jpg' : ext);
      }
      if (section.kind.layout == SectionLayout.colophon && section.zeepubsLogo && zeepubsLogo != null) {
        _imageNames.putIfAbsent(zeepubsLogoName, () => unique('zeepubs', 'png'));
      }
    }
  }

  static String? _headingImageOf(TemplateSection s) => s.kind.layout == SectionLayout.text && s.headingStyle.usesImage && s.headingImage.isNotEmpty ? s.headingImage : null;

  void _assignFontNames() {
    final used = <String>{};
    for (final file in fonts.expand((f) => f.files)) {
      final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
      final stem = sanitizeFileName(p.basenameWithoutExtension(file.path));
      var name = '$stem.$ext';
      for (var n = 2; !used.add(name.toLowerCase()); n++) {
        name = '${stem}_$n.$ext';
      }
      _fontNames[file.path] = name;
    }
  }

  String? get _coverImage {
    final cover = project.sections.where((s) => s.kind == SectionKind.cover).firstOrNull;
    final source = cover?.images.where(_imageNames.containsKey).firstOrNull;
    return source == null ? null : _imageNames[source];
  }

  bool get _hasImages => _imageNames.isNotEmpty;

  // Los ID de XML no pueden empezar por dígito.
  static String _manifestId(String fileName) => RegExp(r'^[A-Za-z_]').hasMatch(fileName) ? fileName : 'x$fileName';

  // ── Paquete ─────────────────────────────────────────────────────────────────

  String _opf() {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="BookId" xml:lang="${_esc(_lang)}">')
      ..writeln('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">');
    _writeMetadata(b);
    b
      ..writeln('  </metadata>')
      ..writeln('  <manifest>');
    for (final section in project.sections) {
      for (final file in _sectionFiles[section]!) {
        b.writeln('    <item id="${_manifestId(file)}" href="Text/$file" media-type="application/xhtml+xml"/>');
      }
    }
    b
      ..writeln('    <item id="${_manifestId(navFileName)}" href="Text/$navFileName" media-type="application/xhtml+xml" properties="nav"/>')
      ..writeln('    <item id="style.css" href="Styles/style.css" media-type="text/css"/>')
      ..writeln('    <item id="nav-style.css" href="Styles/nav-style.css" media-type="text/css"/>');
    final cover = _coverImage;
    for (final name in _imageNames.values) {
      final type = _imageMediaTypes[p.extension(name).substring(1)]!;
      final properties = name == cover ? ' properties="cover-image"' : '';
      b.writeln('    <item id="${_manifestId(name)}" href="Images/$name" media-type="$type"$properties/>');
    }
    for (final name in _fontNames.values) {
      b.writeln('    <item id="${_manifestId(name)}" href="Fonts/$name" media-type="${fontMediaTypes[p.extension(name).substring(1)]}"/>');
    }
    b
      ..writeln('  </manifest>')
      ..writeln('  <spine>');
    for (final section in project.sections) {
      for (final file in _sectionFiles[section]!) {
        b.writeln('    <itemref idref="${_manifestId(file)}"/>');
      }
    }
    b
      ..writeln('    <itemref idref="${_manifestId(navFileName)}" linear="no"/>')
      ..writeln('  </spine>')
      ..writeln('</package>');
    return b.toString();
  }

  void _writeMetadata(StringBuffer b) {
    writeOpfMetadata(b, _meta, now: now);
    void meta(String property, String value) => b.writeln('    <meta property="$property">$value</meta>');
    meta('schema:accessMode', 'textual');
    if (_hasImages) meta('schema:accessMode', 'visual');
    for (final feature in const ['structuralNavigation', 'tableOfContents', 'readingOrder']) {
      meta('schema:accessibilityFeature', feature);
    }
    meta('schema:accessibilityHazard', 'none');
    if (_coverImage case final cover?) b.writeln('    <meta name="cover" content="${_manifestId(cover)}"/>');
  }

  // ── Navegación ──────────────────────────────────────────────────────────────

  String _nav() {
    final b = StringBuffer(_xhtmlHead('Índice', styles: ['nav-style.css', 'style.css']))
      ..writeln('<body epub:type="frontmatter">')
      ..writeln('  <nav epub:type="toc" id="toc" role="doc-toc">')
      ..writeln('    <h1>Índice de contenido</h1>');

    var entries = [
      for (final s in project.sections)
        if (s.inToc) (level: s.level, href: _sectionFiles[s]!.first, label: s.effectiveTocLabel),
    ];
    if (entries.isEmpty) {
      final first = project.sections.first;
      entries = [(level: 1, href: _sectionFiles[first]!.first, label: first.effectiveTocLabel)];
    }
    _writeTocList(b, entries);
    b.writeln('  </nav>');

    final landmarks = <({String type, String href, String label})>[];
    final seen = <String>{};
    void landmark(String type, String href, String label) {
      if (seen.add(type)) landmarks.add((type: type, href: href, label: label));
    }

    for (final s in project.sections) {
      final file = _sectionFiles[s]!.first;
      if (s.matter == BookMatter.body) landmark('bodymatter', file, 'Contenido principal');
      if (s.epubType.isNotEmpty && !_nonLandmarkTypes.contains(s.epubType)) landmark(s.epubType, file, s.effectiveTocLabel);
    }
    landmark('toc', '#toc', 'Índice de contenido');

    b
      ..writeln('  <nav epub:type="landmarks" id="landmarks" hidden="">')
      ..writeln('    <h1>Guías</h1>')
      ..writeln('    <ol>');
    for (final l in landmarks) {
      b.writeln('      <li><a epub:type="${l.type}" href="${l.href}">${_esc(l.label)}</a></li>');
    }
    b
      ..writeln('    </ol>')
      ..writeln('  </nav>')
      ..writeln('</body>')
      ..writeln('</html>');
    return b.toString();
  }

  // Un nivel nunca supera al anterior en más de uno: cada <ol> anidado necesita
  // un <li> padre.
  void _writeTocList(StringBuffer b, List<({int level, String href, String label})> entries) {
    var depth = 0;
    for (final e in entries) {
      final level = e.level.clamp(1, depth + 1);
      if (level > depth) {
        b.writeln('${'  ' * (2 * level)}<ol>');
      } else {
        b.writeln('${'  ' * (2 * depth + 1)}</li>');
        for (var d = depth; d > level; d--) {
          b
            ..writeln('${'  ' * (2 * d)}</ol>')
            ..writeln('${'  ' * (2 * d - 1)}</li>');
        }
      }
      depth = level;
      b
        ..writeln('${'  ' * (2 * depth + 1)}<li>')
        ..writeln('${'  ' * (2 * depth + 2)}<a href="${e.href}">${_esc(e.label)}</a>');
    }
    for (var d = depth; d > 0; d--) {
      b
        ..writeln('${'  ' * (2 * d + 1)}</li>')
        ..writeln('${'  ' * (2 * d)}</ol>');
    }
  }

  // ── Secciones ───────────────────────────────────────────────────────────────

  String _bookDisplayTitle() {
    final local = _meta.altTitles.where((t) => t.lang.trim().toLowerCase().split('-').first == _lang.toLowerCase().split('-').first && t.text.trim().isNotEmpty);
    return local.isNotEmpty ? local.first.text.trim() : _meta.title.trim();
  }

  String _headingText(TemplateSection s) => s.kind.layout == SectionLayout.titlePage && s.title.trim().isEmpty ? _bookDisplayTitle() : s.title.trim();

  String _sectionXhtml(TemplateSection s, int page) {
    final b = StringBuffer(_xhtmlHead(s.effectiveTocLabel))..writeln('<body epub:type="${s.matter.epubType}">');
    if (page == 0) _comment(b, s.kind.purpose, indent: '  ');
    final style = s.kind.layout == SectionLayout.text ? s.headingStyle : HeadingStyle.text;
    // La página del texto tras una separadora sigue siendo la misma sección, con su propio encabezado.
    final hasHeading = page == 0 || style == HeadingStyle.separatorPage;
    final (headingHidden, headingInToc) = switch (style) {
      HeadingStyle.imageTitle => (true, s.inToc),
      HeadingStyle.separatorPage when page == 0 => (true, s.inToc),
      HeadingStyle.separatorPage => (false, false),
      _ => (false, s.inToc),
    };
    final labelledByHeading = hasHeading && !_purposeless(s, hidden: headingHidden, inToc: headingInToc);
    final attrs = [
      if (hasHeading && s.epubType.isNotEmpty) 'epub:type="${_esc(s.epubType)}"',
      if (hasHeading && s.role.isNotEmpty) 'role="${_esc(s.role)}"',
      s.ariaLabel.trim().isNotEmpty || !labelledByHeading ? 'aria-label="${_esc(s.ariaLabel.trim().isEmpty ? s.effectiveTocLabel : s.ariaLabel.trim())}"' : 'aria-labelledby="encabezado"',
    ];
    b.writeln('  <section ${attrs.join(' ')}>');
    final image = _imageNames[_headingImageOf(s)];
    void figure(String className, String alt) => image == null ? _comment(b, 'Aquí va la imagen') : b.writeln('    <figure class="$className"><img src="../Images/$image" alt="${_esc(alt)}"/></figure>');

    switch (style) {
      case HeadingStyle.text:
        if (page == 0) _writeHeading(b, s);
        _writeContent(b, s, page);
      case HeadingStyle.imageBefore:
        figure('logo', '');
        _writeHeading(b, s);
        _writeContent(b, s, page);
      case HeadingStyle.imageAfter:
        _writeHeading(b, s);
        figure('logo', '');
        _writeContent(b, s, page);
      case HeadingStyle.imageTitle:
        _writeHeading(b, s, hidden: true);
        figure('fill', s.effectiveTocLabel);
        _writeContent(b, s, page);
      case HeadingStyle.separatorPage when page == 0:
        _writeHeading(b, s, hidden: true);
        figure('fill', s.effectiveTocLabel);
      case HeadingStyle.separatorPage:
        _writeHeading(b, s, inToc: false);
        _writeContent(b, s, page);
    }
    b
      ..writeln('  </section>')
      ..writeln('</body>')
      ..writeln('</html>');
    return b.toString();
  }

  // Un encabezado oculto existe para que el índice apunte a la sección; fuera del índice no cumple
  // ninguna función y la sección se nombra con aria-label.
  bool _purposeless(TemplateSection s, {required bool hidden, required bool inToc}) => (hidden || s.hideHeading) && !inToc;

  void _writeHeading(StringBuffer b, TemplateSection s, {bool hidden = false, bool? inToc}) {
    final text = _headingText(s);
    final listed = inToc ?? s.inToc;
    if (_purposeless(s, hidden: hidden, inToc: listed)) return;
    final classes = [
      if (s.kind.layout == SectionLayout.titlePage) 'title',
      if (hidden || s.hideHeading) 'hidden',
      if (!listed) 'sigil_not_in_toc',
    ];
    final label = s.effectiveTocLabel;
    final attrs = [
      'id="encabezado"',
      if (classes.isNotEmpty) 'class="${classes.join(' ')}"',
      // Sigil toma este atributo como texto del índice al regenerarlo.
      if (listed && (label != text || s.subtitle.trim().isNotEmpty)) 'title="${_esc(label)}"',
      if (s.kind.layout == SectionLayout.titlePage) 'epub:type="fulltitle"',
    ];
    final subtitle = s.subtitle.trim().isEmpty ? '' : '<br/><small>${_esc(s.subtitle.trim())}</small>';
    final level = s.level.clamp(1, 6);
    b.writeln('    <h$level ${attrs.join(' ')}>${_esc(text)}$subtitle</h$level>');
  }

  void _writeContent(StringBuffer b, TemplateSection s, int page) {
    switch (s.kind.layout) {
      case SectionLayout.text:
        _comment(b, 'Aquí va el contenido');
      case SectionLayout.cover:
        final name = s.images.map((x) => _imageNames[x]).nonNulls.firstOrNull;
        if (name == null) {
          _comment(b, 'Aquí va la imagen de cubierta');
        } else {
          b.writeln('    <figure class="fill"><img role="doc-cover" src="../Images/$name" alt="${_esc('Cubierta de ${_bookDisplayTitle()}')}"/></figure>');
        }
      case SectionLayout.images:
        final names = s.images.map((x) => _imageNames[x]).nonNulls.toList();
        if (page < names.length) {
          final alt = names.length == 1 ? s.title.trim() : '${s.title.trim()} ${page + 1}';
          b.writeln('    <figure class="fill"><img src="../Images/${names[page]}" alt="${_esc(alt)}"/></figure>');
        } else {
          _comment(b, 'Aquí van las imágenes');
        }
      case SectionLayout.titlePage:
        _writeTitlePage(b);
      case SectionLayout.synopsis:
        // Una línea en blanco separa párrafos; un salto simple es un <br/> dentro del párrafo.
        final paragraphs = _meta.description.split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty);
        if (paragraphs.isEmpty) _comment(b, 'Aquí va la sinopsis');
        for (final paragraph in paragraphs) {
          b.writeln('    <p>${paragraph.split('\n').map((line) => _esc(line.trim())).join('<br/>')}</p>');
        }
      case SectionLayout.notice:
        b
          ..writeln('    <blockquote class="warning">')
          ..writeln('      <p class="large align-center"><b>Advertencia:</b></p>')
          ..writeln('      <p class="space-0">${_esc(s.warning.text)}</p>')
          ..writeln('    </blockquote>');
      case SectionLayout.epigraph:
        b
          ..writeln('    <blockquote>')
          ..writeln('      <p class="space-3">Aquí va la cita.</p>')
          ..writeln('    </blockquote>');
      case SectionLayout.colophon:
        final names = [
          ...s.images.map((x) => _imageNames[x]).nonNulls,
          if (s.zeepubsLogo && _imageNames.containsKey(zeepubsLogoName)) _imageNames[zeepubsLogoName]!,
        ];
        if (names.isEmpty) _comment(b, 'Aquí van los logos');
        for (final name in names) {
          b.writeln('    <figure class="logo"><img class="space-3" src="../Images/$name" alt="${_esc('Logo ${p.basenameWithoutExtension(name)}')}"/></figure>');
        }
      case SectionLayout.notes:
        if (!project.guideComments) break;
        b
          ..writeln('    <!-- Formato de cada nota; la llamada en el texto es:')
          ..writeln('    <a href="notas.xhtml#nt1" id="rf1" epub:type="noteref" role="doc-noteref"><sup>&#10094;01&#10095;</sup></a>')
          ..writeln('    <aside class="note" epub:type="endnote" id="nt1">')
          ..writeln('      <p><a href="capitulo01.xhtml#rf1" role="doc-backlink"><sup>&#10094;01&#10095;</sup></a> Texto de la nota.</p>')
          ..writeln('    </aside>')
          ..writeln('    -->');
    }
  }

  void _comment(StringBuffer b, String text, {String indent = '    '}) {
    if (project.guideComments) b.writeln('$indent<!-- $text -->');
  }

  void _writeTitlePage(StringBuffer b) {
    final m = _meta;
    final volume = m.hasSeries ? 'Volumen ${m.seriesIndex.trim().padLeft(2, '0')}' : 'Volumen único';
    final type = m.bookType.trim().isEmpty ? '' : '<br/><small>[${_esc(m.bookType.trim())}]</small>';
    b
      ..writeln('    <h2 class="subtitle sigil_not_in_toc" role="doc-subtitle">$volume$type</h2>')
      ..writeln('    <div class="align-center" epub:type="copyright-page">');

    final people = m.actors.where((a) => a.name.trim().isNotEmpty);
    var previousCreator = true;
    var first = true;
    for (final role in MarcRelator.values) {
      final names = [
        for (final a in people)
          if (a.roles.contains(role)) _creditName(a),
      ];
      if (names.isEmpty) continue;
      final gap = first || previousCreator != role.creator ? ' class="space-1"' : '';
      b.writeln('      <p$gap><b>${role.credit}:</b> ${names.join(', ')}</p>');
      previousCreator = role.creator;
      first = false;
    }
    for (final link in m.links.where((l) => l.url.trim().isNotEmpty)) {
      final url = _esc(link.url.trim());
      final label = link.label.trim().isEmpty ? '' : '<b>${_esc(link.label.trim())}</b><br/>';
      b.writeln('      <p class="space-1">$label<a href="$url">$url</a></p>');
    }
    b.writeln('    </div>');
  }

  String _creditName(Actor a) {
    final alt = a.altNames.where((t) => t.text.trim().isNotEmpty && t.lang.trim().isNotEmpty).firstOrNull;
    if (alt == null) return _esc(a.name.trim());
    final lang = _esc(alt.lang.trim());
    return '${_esc(a.name.trim())} (<span lang="$lang" xml:lang="$lang">${_esc(alt.text.trim())}</span>)';
  }

  // Va al final de la hoja, dentro de la personalización.
  String _fontCss() {
    final b = StringBuffer();
    for (final (:font, :files) in fonts) {
      if (files.isEmpty) continue;
      final family = '"${font.family.replaceAll('"', '')}"';
      if (b.isEmpty) b.write('\n/* Fuentes incrustadas */\n');
      for (final f in files) {
        final weight = switch (f.weight) {
          400 => 'normal',
          700 => 'bold',
          final w => '$w',
        };
        b
          ..writeln('@font-face {')
          ..writeln('  font-family: $family;')
          ..writeln('  font-weight: $weight;')
          ..writeln('  font-style: ${f.italic ? 'italic' : 'normal'};')
          ..writeln('  src: url(../Fonts/${_fontNames[f.path]});')
          ..writeln('}');
      }
      final selectors = [
        for (final level in font.headingLevels.toSet().toList()..sort())
          if (level <= 6) ...['h$level', if (level == 1) 'h1.title', if (level == 2) 'h2.subtitle'] else '.h$level',
        '.${font.cssClass}',
      ];
      b
        ..writeln('${selectors.join(',\n')} {')
        ..writeln('  font-family: $family, ${font.fallback.css};')
        ..writeln('}');
    }
    return b.toString();
  }

  String _customCss() {
    final css = project.customCss.trim();
    return css.isEmpty ? '' : '\n$css\n';
  }

  String _xhtmlHead(String title, {List<String> styles = const ['style.css']}) {
    final lang = _esc(_lang);
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="$lang" xml:lang="$lang">')
      ..writeln('<head>')
      ..writeln('  <meta charset="utf-8"/>')
      ..writeln('  <title>${_esc(title)}</title>');
    for (final style in styles) {
      b.writeln('  <link href="../Styles/$style" rel="stylesheet" type="text/css"/>');
    }
    b.writeln('</head>');
    return b.toString();
  }
}

// Comentarios de la hoja de estilos que solo orientan al maquetador.
const _guideCssComments = [
  '/* Reglas propias de cada libro; quitar las que no se usen */',
  '/* Niveles 7 a 9: <p class="h7" role="heading" aria-level="7"> */',
];

String _withoutGuideComments(String css) => css.split('\n').where((line) => !_guideCssComments.contains(line.trim())).join('\n');

const _esc = xmlEscape;

const _containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

// specified-fonts permite que Apple Books use las fuentes incrustadas que se
// añadan después en la sección de personalización.
const _appleOptionsXml = '''<?xml version="1.0" encoding="UTF-8"?>
<display_options>
  <platform name="*">
    <option name="specified-fonts">true</option>
  </platform>
</display_options>
''';
