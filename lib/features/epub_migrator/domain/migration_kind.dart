import '/features/epub_templater/domain/section_kind.dart';

// Tipo de cada documento del libro migrado, con lo que el template fija para él.
// [matter] nulo: la división sale de la posición del documento.
enum MigrationKind {
  cover('Cubierta', 'cubierta', 'cover', BookMatter.front, hidden: true),
  notice('Advertencia', 'advertencia', 'notice', null, inToc: false, hidden: true),
  synopsis('Sinopsis', 'sinopsis', 'abstract', BookMatter.front, inToc: false),
  illustrations('Ilustraciones', 'resumen', '', BookMatter.front, hidden: true),
  authorProfile('Acerca del autor(a)', 'perfil', 'foreword', BookMatter.front),
  titlePage('Página de título', 'titulo', 'titlepage', BookMatter.front),
  credits('Créditos', 'creditos', 'other-credits', null),
  colophon('Logos', 'logos', 'colophon', BookMatter.front, inToc: false, hidden: true),
  contentsImage('Contenido', 'contenido', '', BookMatter.front, hidden: true),
  promo('Otras obras', 'promo', '', null, inToc: false, hidden: true),
  characters('Personajes', 'personajes', '', null),
  glossary('Glosario', 'glosario', 'glossary', null),
  introduction('Introducción', 'introduccion', 'introduction', null),
  dedication('Dedicatoria', 'dedicatoria', 'dedication', BookMatter.front, hidden: true),
  epigraph('Epígrafe', 'epigrafe', 'epigraph', BookMatter.front, hidden: true),
  preface('Prefacio', 'prefacio', 'preface', BookMatter.front),
  prologue('Prólogo', 'prologo', 'prologue', BookMatter.body),
  part('Parte', 'parte', 'part', BookMatter.body, numbered: true),
  chapter('Capítulo', 'capitulo', 'chapter', BookMatter.body, numbered: true),
  epilogue('Epílogo', 'epilogo', 'epilogue', BookMatter.body),
  appendix('Apéndice', 'extra', 'appendix', BookMatter.body, numbered: true),
  generic('Sección', 'seccion', '', null, numbered: true),
  afterword('Palabras del autor', 'autor', 'afterword', BookMatter.back),
  translatorNotes('Palabras del traductor', 'traductor', 'conclusion', BookMatter.back),
  acknowledgments('Agradecimientos', 'agradecimientos', 'acknowledgments', BookMatter.back),
  bibliography('Bibliografía', 'bibliografia', 'bibliography', BookMatter.back),
  backCover('Contracubierta', 'contracubierta', '', BookMatter.back, inToc: false, hidden: true),
  endnotes('Notas', 'notas', 'endnotes', BookMatter.back, inToc: false);

  const MigrationKind(this.title, this.fileName, this.epubType, this.matter, {this.inToc = true, this.hidden = false, this.numbered = false});

  final String title;
  final String fileName;
  final String epubType;
  final BookMatter? matter;
  final bool inToc;
  final bool hidden;
  // Los numerados llevan dos cifras en el nombre de archivo (capitulo01).
  final bool numbered;

  String get role => epubTypeRoles[epubType] ?? '';
}

// Páginas seguidas del mismo tipo que forman una sola sección.
const groupKinds = {MigrationKind.titlePage, MigrationKind.illustrations, MigrationKind.contentsImage, MigrationKind.synopsis, MigrationKind.backCover, MigrationKind.colophon, MigrationKind.characters, MigrationKind.promo};

// epub:type del template anterior → tipo.
const oldEpubTypes = {
  'cover': MigrationKind.cover,
  'notice': MigrationKind.notice,
  'abstract': MigrationKind.synopsis,
  'introduction': MigrationKind.illustrations,
  'titlepage': MigrationKind.titlePage,
  'copyright-page': MigrationKind.titlePage,
  'colophon': MigrationKind.colophon,
  'toc': MigrationKind.contentsImage,
  'dedication': MigrationKind.dedication,
  'epigraph': MigrationKind.epigraph,
  'preface': MigrationKind.preface,
  'foreword': MigrationKind.authorProfile,
  'preamble': MigrationKind.preface,
  'prologue': MigrationKind.prologue,
  'part': MigrationKind.part,
  'chapter': MigrationKind.chapter,
  'epilogue': MigrationKind.epilogue,
  'ultilogue': MigrationKind.epilogue,
  'appendix': MigrationKind.appendix,
  'afterword': MigrationKind.afterword,
  'conclusion': MigrationKind.translatorNotes,
  'acknowledgments': MigrationKind.acknowledgments,
  'rearnotes': MigrationKind.endnotes,
  'endnotes': MigrationKind.endnotes,
  'footnotes': MigrationKind.endnotes,
  'other-credits': MigrationKind.credits,
  'contributors': MigrationKind.credits,
};

final _fileKinds = [
  (RegExp(r'^(cubierta|portada|cover)'), MigrationKind.cover),
  (RegExp(r'^(contracubierta|contraportada|backcover)'), MigrationKind.backCover),
  (RegExp(r'^(advertencia|aviso)'), MigrationKind.notice),
  (RegExp(r'^(sinopsis|synopsis)'), MigrationKind.synopsis),
  (RegExp(r'^(ilustrador|illustrator)'), MigrationKind.afterword),
  (RegExp(r'^(resumen|ilustraciones?|ilustra(?!dor)|color|insert)'), MigrationKind.illustrations),
  (RegExp(r'^perfil'), MigrationKind.authorProfile),
  (RegExp(r'^(titulo|title)'), MigrationKind.titlePage),
  (RegExp(r'^(creditos|credits|derechos)'), MigrationKind.credits),
  (RegExp(r'^logos?'), MigrationKind.colophon),
  (RegExp(r'^(contenido|indice|contents|toc)([\s_-]*(img|imagen|image))?$'), MigrationKind.contentsImage),
  (RegExp(r'^(promo|publicidad|anuncio)'), MigrationKind.promo),
  (RegExp(r'^(personajes|characters)'), MigrationKind.characters),
  (RegExp(r'^(glosario|glossary)'), MigrationKind.glossary),
  (RegExp(r'^(introduccion|introduction)$'), MigrationKind.introduction),
  (RegExp(r'^(bibliografia|bibliography)'), MigrationKind.bibliography),
  (RegExp(r'^dedicatoria'), MigrationKind.dedication),
  (RegExp(r'^epigrafe'), MigrationKind.epigraph),
  (RegExp(r'^(prefacio|preface)'), MigrationKind.preface),
  (RegExp(r'^(prologo|prologue)'), MigrationKind.prologue),
  (RegExp(r'^(parte|part)\b'), MigrationKind.part),
  (RegExp(r'^(epilogo|epilogue)'), MigrationKind.epilogue),
  (RegExp(r'^(apendice|appendix|extra|bonus|historiacorta|historia|ss|side)'), MigrationKind.appendix),
  (RegExp(r'^(autor|afterword)'), MigrationKind.afterword),
  (RegExp(r'^traductor'), MigrationKind.translatorNotes),
  (RegExp(r'^agradecimientos'), MigrationKind.acknowledgments),
  (RegExp(r'^(notas|notes)'), MigrationKind.endnotes),
  (RegExp(r'^(section|cap|capitulo|chapter|c\d|interludio|intermedio|interlude)'), MigrationKind.chapter),
];

// El texto del encabezado manda sobre el archivo y el epub:type antiguo.
final _headingKinds = [
  (RegExp(r'^pr[oó]logo\b'), MigrationKind.prologue),
  (RegExp(r'^ep[ií]logo\b(?!.*autor)'), MigrationKind.epilogue),
  (RegExp(r'^(aviso|advertencia|anuncio)\b'), MigrationKind.notice),
  (RegExp(r'^(palabras|notas?|comentarios?|mensaje) del? (la )?autor'), MigrationKind.afterword),
  (RegExp(r'^(postfacio|posfacio|epílogo del autor)'), MigrationKind.afterword),
  (RegExp(r'^(palabras|notas?|comentarios?|mensaje) del? (los )?traductor'), MigrationKind.translatorNotes),
  (RegExp(r'^agradecimientos\b'), MigrationKind.acknowledgments),
  (RegExp(r'^cr[eé]ditos\b'), MigrationKind.credits),
  // Historias extra (SS, bonus del libro electrónico): apéndices, no capítulos.
  (RegExp(r'^((cap[ií]tulo|historia|relato|cuento)\s+)?(ss|extra|bonus|especial)\b'), MigrationKind.appendix),
  (RegExp(r'^(historia|relato|cuento)s?\s+(corta|corto|extra|especial|adicional)'), MigrationKind.appendix),
  (RegExp(r'^interludio\b'), MigrationKind.chapter),
  (RegExp(r'^(cap[ií]tulo|chapter)\b'), MigrationKind.chapter),
  (RegExp(r'^(parte|part)\s+[\divxlc]+\b'), MigrationKind.part),
  (RegExp(r'^dedicatoria\b'), MigrationKind.dedication),
  (RegExp(r'^sinopsis\b'), MigrationKind.synopsis),
  (RegExp(r'^(ilustraciones|ilustraciones a color|galer[ií]a)$'), MigrationKind.illustrations),
  (RegExp(r'^personajes\b'), MigrationKind.characters),
  (RegExp(r'^glosario\b'), MigrationKind.glossary),
];

// Nombres que da la etiqueta antes que el tipo (secciones del autor que comparten tipo).
final labelFileNames = [
  (RegExp(r'^(palabras|notas?|comentarios?|mensaje) del? (la )?ilustrador', caseSensitive: false), 'ilustrador'),
  (RegExp(r'^(acerca|sobre) del? (la )?autor', caseSensitive: false), 'perfil'),
  (RegExp(r'^cr[eé]ditos\b', caseSensitive: false), 'creditos'),
  (RegExp(r'^ap[eé]ndice\b', caseSensitive: false), 'apendice'),
];

MigrationKind? headingKind(String label) {
  final s = label.trim().toLowerCase();
  return _headingKinds.where((k) => k.$1.hasMatch(s)).firstOrNull?.$2;
}

MigrationKind? fileKind(String stem) {
  final s = stem.toLowerCase().replaceFirst(RegExp(r'[\s_-]*\d+([\s_-]+\d+)*$'), '').replaceAll('í', 'i').replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('ó', 'o').replaceAll('ú', 'u');
  return _fileKinds.where((k) => k.$1.hasMatch(s)).firstOrNull?.$2;
}
