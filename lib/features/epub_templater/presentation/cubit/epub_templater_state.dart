part of 'epub_templater_cubit.dart';

// Sin == propio: la vista lo muestra una vez por instancia.
class EpubTemplaterMessage {
  const EpubTemplaterMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class EpubTemplaterState with _$EpubTemplaterState {
  const factory EpubTemplaterState({
    required TemplateProject project,
    @Default({}) Map<String, TemplateProject> profiles,
    String? selectedKey,
    // Cambia cuando el proyecto se reemplaza entero, para reiniciar los campos del formulario.
    @Default(0) int revision,
    @Default(false) bool generating,
    EpubTemplaterMessage? message,
    required List<ImageFormat> allowedFormats,
    @Default(true) bool allowConversion,
    required QualityMode qualityMode,
    // Clave: ruta de la imagen de origen.
    @Default({}) Map<String, ImageJob> imageJobs,
    @Default(false) bool optimizing,
    String? optimizeStatus,
  }) = _EpubTemplaterState;
}

extension EpubTemplaterStateX on EpubTemplaterState {
  TemplateSection? get selected => project.sections.where((s) => s.key == selectedKey).firstOrNull;

  // Rutas de todas las imágenes que usa la plantilla, sin repetir y en orden.
  List<String> get imagePaths => {
    for (final s in project.sections) ...[
      ...s.images,
      if (s.kind.layout == SectionLayout.text && s.headingStyle.usesImage && s.headingImage.isNotEmpty) s.headingImage,
    ],
  }.toList();

  Map<String, OptimizedOutcome> get optimizedImages => {
    for (final MapEntry(:key, :value) in imageJobs.entries)
      if (value case DoneJob(outcome: final OptimizedOutcome outcome)) key: outcome,
  };
}
