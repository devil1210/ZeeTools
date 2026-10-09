// Subconjunto de los códigos de función MARC (https://id.loc.gov/vocabulary/relators)
// usados en novelas traducidas. [credit] es la etiqueta en los créditos de la
// página de título; [creator] indica si la función corresponde a dc:creator y
// [code] es el código que se escribe en el OPF.
enum MarcRelator {
  aut('Autor', 'Autor', creator: true),
  ill('Ilustrador', 'Ilustraciones', creator: true),
  art('Artista', 'Arte', creator: true),
  ant('Obra original', 'Obra original', creator: true),
  cov('Diseñador de cubierta', 'Cubierta'),
  trl('Traductor', 'Traducción'),
  edt('Editor', 'Edición'),
  pfr('Corrector', 'Corrección'),
  rev('Revisor', 'Revisión'),
  mrk('Maquetador', 'Epub'),
  bkp('Productor del libro', 'Producción'),
  pbl('Editorial', 'Publicación'),
  dst('Distribuidor', 'Distribución'),
  ctb('Colaborador', 'Colaboración'),
  // MARC no tiene un código para quien traduce o retoca las imágenes: en el OPF es un colaborador más.
  imageEditor('Editor de imágenes', 'Edición de imágenes'),
  // Honoree: a quien el libro agradece su ayuda.
  hnr('Agradecimiento especial', 'Agradecimientos especiales');

  const MarcRelator(this.label, this.credit, {this.creator = false});

  final String label;
  final String credit;
  final bool creator;

  String get code => switch (this) {
    imageEditor => ctb.name,
    _ => name,
  };
}
