part of 'epub_migrator_cubit.dart';

// Sin == propio: la vista lo muestra una vez por instancia.
class EpubMigratorMessage {
  const EpubMigratorMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class EpubMigratorState with _$EpubMigratorState {
  const factory EpubMigratorState({
    MigrationProject? project,
    @Default(false) bool busy,
    // Cambia al abrir o cerrar un libro, para reiniciar los campos de los formularios.
    @Default(0) int revision,
    EpubMigratorMessage? message,
    // Cambios automáticos de la última migración guardada.
    List<MigrationIssue>? written,
  }) = _EpubMigratorState;
}

extension EpubMigratorStateX on EpubMigratorState {
  List<MigrationIssue> get issues => project == null ? const [] : migrationIssues(project!);
}
