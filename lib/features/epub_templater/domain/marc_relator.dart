// Subconjunto de los códigos de función MARC (https://id.loc.gov/vocabulary/relators)
// usados en novelas traducidas. [credit] es la etiqueta en los créditos de la
// página de título; [creator] indica si la función corresponde a dc:creator.
enum MarcRelator {
  aut('Autor', 'Autor', creator: true),
  ill('Ilustrador', 'Ilustraciones', creator: true),
  art('Artista', 'Arte', creator: true),
  ant('Obra original', 'Obra original', creator: true),
  cov('Diseñador de cubierta', 'Cubierta'),
  trl('Traductor', 'Traducción'),
  edt('Editor de imágenes', 'Edición de imágenes'),
  pfr('Corrector', 'Corrección'),
  rev('Revisor', 'Revisión'),
  mrk('Maquetador', 'Epub'),
  bkp('Productor del libro', 'Producción'),
  pbl('Editorial', 'Publicación'),
  dst('Distribuidor', 'Distribución'),
  ctb('Colaborador', 'Colaboración'),
  // Honoree: a quien el libro agradece su ayuda.
  hnr('Agradecimiento especial', 'Agradecimientos especiales');

  const MarcRelator(this.label, this.credit, {this.creator = false});

  final String label;
  final String credit;
  final bool creator;
}
