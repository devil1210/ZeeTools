enum BookMatter {
  front('frontmatter', 'Preliminares'),
  body('bodymatter', 'Cuerpo de la obra'),
  back('backmatter', 'Páginas finales');

  const BookMatter(this.epubType, this.label);

  final String epubType;
  final String label;
}

// Determina el contenido inicial que se genera dentro de la sección.
enum SectionLayout {
  text,
  cover,
  images,
  titlePage,
  synopsis,
  notice,
  epigraph,
  colophon,
  notes,
}

// Valores por defecto de cada tipo de sección.
enum SectionKind {
  cover(
    label: 'Cubierta',
    fileName: 'cubierta',
    title: 'Cubierta',
    epubType: 'cover',
    matter: BookMatter.front,
    layout: SectionLayout.cover,
    hideHeading: true,
  ),
  notice(
    label: 'Advertencia',
    fileName: 'advertencia',
    title: 'Advertencia',
    epubType: 'notice',
    matter: BookMatter.front,
    layout: SectionLayout.notice,
    inToc: false,
    hideHeading: true,
  ),
  synopsis(
    label: 'Sinopsis',
    fileName: 'sinopsis',
    title: 'Sinopsis',
    epubType: 'abstract',
    matter: BookMatter.front,
    layout: SectionLayout.synopsis,
    inToc: false,
  ),
  illustrations(
    label: 'Ilustraciones',
    fileName: 'resumen',
    title: 'Ilustraciones',
    matter: BookMatter.front,
    layout: SectionLayout.images,
    hideHeading: true,
  ),
  authorProfile(
    label: 'Acerca del autor',
    fileName: 'perfil',
    title: 'Acerca del autor(a)',
    epubType: 'foreword',
    matter: BookMatter.front,
  ),
  titlePage(
    label: 'Página de título',
    fileName: 'titulo',
    title: 'Página de título',
    epubType: 'titlepage',
    matter: BookMatter.front,
    layout: SectionLayout.titlePage,
  ),
  colophon(
    label: 'Logos',
    fileName: 'logos',
    title: 'Logos',
    epubType: 'colophon',
    matter: BookMatter.front,
    layout: SectionLayout.colophon,
    inToc: false,
    hideHeading: true,
  ),
  contentsImage(
    label: 'Contenido',
    fileName: 'contenido',
    title: 'Contenido',
    matter: BookMatter.front,
    layout: SectionLayout.images,
    hideHeading: true,
  ),
  dedication(
    label: 'Dedicatoria',
    fileName: 'dedicatoria',
    title: 'Dedicatoria',
    epubType: 'dedication',
    matter: BookMatter.front,
    hideHeading: true,
  ),
  epigraph(
    label: 'Epígrafe',
    fileName: 'epigrafe',
    title: 'Epígrafe',
    epubType: 'epigraph',
    matter: BookMatter.front,
    layout: SectionLayout.epigraph,
    hideHeading: true,
  ),
  preface(
    label: 'Prefacio',
    fileName: 'prefacio',
    title: 'Prefacio',
    epubType: 'preface',
    matter: BookMatter.front,
  ),
  prologue(
    label: 'Prólogo',
    fileName: 'prologo',
    title: 'Prólogo',
    epubType: 'prologue',
    matter: BookMatter.body,
  ),
  part(
    label: 'Parte',
    fileName: 'parte',
    title: 'Parte',
    epubType: 'part',
    matter: BookMatter.body,
    numbered: true,
  ),
  chapter(
    label: 'Capítulo',
    fileName: 'capitulo',
    title: 'Capítulo',
    epubType: 'chapter',
    matter: BookMatter.body,
    numbered: true,
  ),
  interlude(
    label: 'Interludio',
    fileName: 'interludio',
    title: 'Interludio',
    epubType: 'chapter',
    matter: BookMatter.body,
    numbered: true,
  ),
  epilogue(
    label: 'Epílogo',
    fileName: 'epilogo',
    title: 'Epílogo',
    epubType: 'epilogue',
    matter: BookMatter.body,
  ),
  afterword(
    label: 'Palabras del autor',
    fileName: 'autor',
    title: 'Palabras del autor',
    epubType: 'afterword',
    matter: BookMatter.back,
  ),
  translatorNotes(
    label: 'Palabras del traductor',
    fileName: 'traductor',
    title: 'Palabras del traductor',
    epubType: 'conclusion',
    matter: BookMatter.back,
  ),
  acknowledgments(
    label: 'Agradecimientos',
    fileName: 'agradecimientos',
    title: 'Agradecimientos',
    epubType: 'acknowledgments',
    matter: BookMatter.back,
  ),
  appendix(
    label: 'Apéndice',
    fileName: 'apendice',
    title: 'Apéndice',
    epubType: 'appendix',
    matter: BookMatter.body,
  ),
  backCover(
    label: 'Contracubierta',
    fileName: 'contracubierta',
    title: 'Contracubierta',
    matter: BookMatter.back,
    layout: SectionLayout.images,
    inToc: false,
    hideHeading: true,
  ),
  endnotes(
    label: 'Notas',
    fileName: 'notas',
    title: 'Notas',
    epubType: 'endnotes',
    matter: BookMatter.back,
    layout: SectionLayout.notes,
    inToc: false,
  ),
  generic(
    label: 'Sección libre',
    fileName: 'seccion',
    title: 'Sección',
    matter: BookMatter.body,
  );

  const SectionKind({
    required this.label,
    required this.fileName,
    required this.title,
    this.epubType = '',
    required this.matter,
    this.layout = SectionLayout.text,
    this.inToc = true,
    this.hideHeading = false,
    this.numbered = false,
  });

  final String label;
  final String fileName;
  final String title;
  final String epubType;
  final BookMatter matter;
  final SectionLayout layout;
  final bool inToc;
  final bool hideHeading;
  // Las secciones numeradas toman nombre de archivo y título con su número de orden.
  final bool numbered;

  bool get acceptsImages => layout == SectionLayout.cover || layout == SectionLayout.images || layout == SectionLayout.colophon;

  bool get singleImage => layout == SectionLayout.cover;
}

// Términos de semántica estructural de EPUB con sentido a nivel de sección y
// su rol DPUB-ARIA admitido en <section>; vacío cuando no existe equivalente.
// La cubierta lleva su rol en la imagen.
const epubTypeRoles = {
  'abstract': 'doc-abstract',
  'acknowledgments': 'doc-acknowledgments',
  'afterword': 'doc-afterword',
  'appendix': 'doc-appendix',
  'chapter': 'doc-chapter',
  'colophon': 'doc-colophon',
  'conclusion': 'doc-conclusion',
  'contributors': '',
  'copyright-page': '',
  'cover': '',
  'dedication': 'doc-dedication',
  'endnotes': 'doc-endnotes',
  'epigraph': 'doc-epigraph',
  'epilogue': 'doc-epilogue',
  'errata': 'doc-errata',
  'foreword': 'doc-foreword',
  'glossary': 'doc-glossary',
  'halftitlepage': '',
  'imprint': '',
  'introduction': 'doc-introduction',
  'notice': 'doc-notice',
  'other-credits': 'doc-credits',
  'part': 'doc-part',
  'preamble': '',
  'preface': 'doc-preface',
  'prologue': 'doc-prologue',
  'subchapter': '',
  'titlepage': '',
  'toc': 'doc-toc',
  'volume': '',
};

// Disposición de una imagen junto al encabezado en las secciones de texto.
enum HeadingStyle {
  text('Solo texto'),
  imageBefore('Imagen antes del título'),
  imageAfter('Imagen después del título'),
  imageTitle('Título en imagen'),
  // El índice apunta a una página con la imagen y el título visible abre la siguiente.
  separatorPage('Página separadora');

  const HeadingStyle(this.label);

  final String label;

  bool get usesImage => this != text;
}
