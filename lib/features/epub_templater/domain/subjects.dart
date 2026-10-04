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

const bookTypes = ['Novela Ligera', 'Novela Web'];

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
