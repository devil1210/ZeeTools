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
    purpose: 'Cubierta: la imagen de portada del volumen.',
    fileName: 'cubierta',
    title: 'Cubierta',
    epubType: 'cover',
    matter: BookMatter.front,
    layout: SectionLayout.cover,
    hideHeading: true,
  ),
  notice(
    label: 'Advertencia',
    purpose: 'Advertencia sobre el contenido, antes de empezar la lectura.',
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
    purpose: 'Sinopsis: el texto de la contraportada o el resumen del volumen.',
    fileName: 'sinopsis',
    title: 'Sinopsis',
    epubType: 'abstract',
    matter: BookMatter.front,
    layout: SectionLayout.synopsis,
    inToc: false,
  ),
  illustrations(
    label: 'Ilustraciones',
    purpose: 'Ilustraciones a color del inicio del volumen, una por página.',
    fileName: 'resumen',
    title: 'Ilustraciones',
    matter: BookMatter.front,
    layout: SectionLayout.images,
    hideHeading: true,
  ),
  authorProfile(
    label: 'Acerca del autor',
    purpose: 'Presentación del autor o del ilustrador al inicio del volumen.',
    fileName: 'perfil',
    title: 'Acerca del autor(a)',
    epubType: 'foreword',
    matter: BookMatter.front,
  ),
  titlePage(
    label: 'Página de título',
    purpose: 'Página de título con los créditos de la edición.',
    fileName: 'titulo',
    title: 'Página de título',
    epubType: 'titlepage',
    matter: BookMatter.front,
    layout: SectionLayout.titlePage,
  ),
  colophon(
    label: 'Logos',
    purpose: 'Logos del grupo de traducción y de los colaboradores.',
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
    purpose: 'Índice original del volumen como imagen.',
    fileName: 'contenido',
    title: 'Contenido',
    matter: BookMatter.front,
    layout: SectionLayout.images,
    hideHeading: true,
  ),
  dedication(
    label: 'Dedicatoria',
    purpose: 'Dedicatoria del autor.',
    fileName: 'dedicatoria',
    title: 'Dedicatoria',
    epubType: 'dedication',
    matter: BookMatter.front,
    hideHeading: true,
  ),
  epigraph(
    label: 'Epígrafe',
    purpose: 'Cita o fragmento breve que abre la obra.',
    fileName: 'epigrafe',
    title: 'Epígrafe',
    epubType: 'epigraph',
    matter: BookMatter.front,
    layout: SectionLayout.epigraph,
    hideHeading: true,
  ),
  preface(
    label: 'Prefacio',
    purpose: 'Prefacio: texto del autor previo a la historia.',
    fileName: 'prefacio',
    title: 'Prefacio',
    epubType: 'preface',
    matter: BookMatter.front,
  ),
  prologue(
    label: 'Prólogo',
    purpose: 'Prólogo: la primera parte de la narración.',
    fileName: 'prologo',
    title: 'Prólogo',
    epubType: 'prologue',
    matter: BookMatter.body,
  ),
  part(
    label: 'Parte',
    purpose: 'Inicio de una parte que agrupa varios capítulos.',
    fileName: 'parte',
    title: 'Parte',
    epubType: 'part',
    matter: BookMatter.body,
    numbered: true,
  ),
  chapter(
    label: 'Capítulo',
    purpose: 'Capítulo de la historia.',
    fileName: 'capitulo',
    title: 'Capítulo',
    epubType: 'chapter',
    matter: BookMatter.body,
    numbered: true,
  ),
  interlude(
    label: 'Interludio',
    purpose: 'Interludio entre capítulos, dentro de la narración.',
    fileName: 'interludio',
    title: 'Interludio',
    epubType: 'chapter',
    matter: BookMatter.body,
    numbered: true,
  ),
  epilogue(
    label: 'Epílogo',
    purpose: 'Epílogo: el cierre de la narración.',
    fileName: 'epilogo',
    title: 'Epílogo',
    epubType: 'epilogue',
    matter: BookMatter.body,
  ),
  afterword(
    label: 'Palabras del autor',
    purpose: 'Palabras finales del autor.',
    fileName: 'autor',
    title: 'Palabras del autor',
    epubType: 'afterword',
    matter: BookMatter.back,
  ),
  translatorNotes(
    label: 'Palabras del traductor',
    purpose: 'Palabras del traductor o del grupo.',
    fileName: 'traductor',
    title: 'Palabras del traductor',
    epubType: 'conclusion',
    matter: BookMatter.back,
  ),
  acknowledgments(
    label: 'Agradecimientos',
    purpose: 'Agradecimientos.',
    fileName: 'agradecimientos',
    title: 'Agradecimientos',
    epubType: 'acknowledgments',
    matter: BookMatter.back,
  ),
  appendix(
    label: 'Apéndice',
    purpose: 'Apéndice o capítulo extra después de la historia principal.',
    fileName: 'apendice',
    title: 'Apéndice',
    epubType: 'appendix',
    matter: BookMatter.body,
  ),
  backCover(
    label: 'Contracubierta',
    purpose: 'Contracubierta: la imagen de la contraportada.',
    fileName: 'contracubierta',
    title: 'Contracubierta',
    matter: BookMatter.back,
    layout: SectionLayout.images,
    inToc: false,
    hideHeading: true,
  ),
  endnotes(
    label: 'Notas',
    purpose: 'Notas del traductor enlazadas desde el texto.',
    fileName: 'notas',
    title: 'Notas',
    epubType: 'endnotes',
    matter: BookMatter.back,
    layout: SectionLayout.notes,
    inToc: false,
  ),
  generic(
    label: 'Sección libre',
    purpose: 'Sección sin un tipo específico.',
    fileName: 'seccion',
    title: 'Sección',
    matter: BookMatter.body,
  );

  const SectionKind({
    required this.label,
    required this.purpose,
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
  // Qué parte de la novela contiene; se escribe como comentario de guía.
  final String purpose;
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
