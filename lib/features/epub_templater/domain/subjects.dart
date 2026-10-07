const literaryGenres = [
  'Acción',
  'Aventura',
  'Bélico',
  'Ciencia ficción',
  'Comedia',
  'Deporte',
  'Drama',
  'Erótico',
  'Escolar',
  'Fantasía',
  'Histórico',
  'LGBTQI+',
  'Misterio',
  'Parodia',
  'Policial',
  'Psicológico',
  'Recuentos de la vida',
  'Romance',
  'Sobrenatural',
  'Terror',
];

// Características de la edición: no son géneros, se escriben después de ellos.
const editionFeatures = ['A color', 'Sin censura'];

const bookTypes = ['Novela', 'Novela ligera', 'Novela web'];

// Etiqueta que lleva al final el nombre de la serie principal según el tipo de libro.
const _seriesTags = {'Novela': 'N', 'Novela ligera': 'NL', 'Novela web': 'NW'};
final _seriesTag = RegExp(r'\s*\[(?:N|NL|NW)\]$');

// La serie sin la etiqueta del tipo, tal como se edita en el formulario.
String seriesWithoutTag(String series) => series.trim().replaceFirst(_seriesTag, '');

// La serie como se escribe en el OPF: «Serie [NL]».
String taggedSeries(String series, String bookType) => switch (_seriesTags[catalogValue(bookTypes, bookType)]) {
  final tag? => '${seriesWithoutTag(series)} [$tag]',
  null => seriesWithoutTag(series),
};

// El valor de [catalog] que corresponde a [value] sin distinguir mayúsculas:
// los EPUB antiguos escriben «Sin Censura» o «Novela Ligera».
String? catalogValue(Iterable<String> catalog, String value) {
  final key = value.trim().toLowerCase();
  return catalog.where((c) => c.toLowerCase() == key).firstOrNull;
}

// EPUB no define demografías: se escriben como dc:subject. La general se añade
// junto a la específica para que una búsqueda por edad abarque ambos públicos.
enum Demographic {
  josei('Adultas/Josei', 'Maduro'),
  seinen('Adultos/Seinen', 'Maduro'),
  shoujo('Chicas/Shoujo', 'Juvenil'),
  shounen('Chicos/Shounen', 'Juvenil');

  const Demographic(this.label, this.ageGroup);

  final String label;
  final String ageGroup;
}
