// Textos de la sección de advertencia: los mismos en todos los libros.
enum ContentWarning {
  explicit(
    'Contenido explícito',
    'Esta novela contiene material y/o lenguaje que para algunos podría resultar ofensivo, explícito y vulgar; '
        'si usted es una persona sensible, se recomienda abstenerse de leerlo.',
  ),
  mature(
    'Título maduro',
    'Este título ha sido clasificado como maduro, por lo tanto, puede contener violencia intensa, sangre/gore, '
        'contenido sexual y/o lenguaje fuerte que puede no ser apropiado para lectores menores de edad.',
  ),
  sensitive(
    'Temas sensibles',
    'Esta novela contiene temas relacionados con depresión, suicidio, bullying y autodesprecio; '
        'si usted es una persona sensible, se recomienda abstenerse de leerlo.',
  ),
  aiTranslation(
    'Traducción con IA',
    'Este volumen fue traducido con una Inteligencia Artificial y revisado por una persona. '
        'Puede contener imprecisiones o interpretaciones personales.',
  );

  const ContentWarning(this.label, this.text);

  final String label;
  final String text;
}
