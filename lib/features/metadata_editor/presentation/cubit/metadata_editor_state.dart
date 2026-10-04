part of 'metadata_editor_cubit.dart';

typedef EditedEpub = ({String path, BookMetadata metadata});

typedef MetadataEditorMessage = ({String text, bool isError});

@Freezed(makeCollectionsUnmodifiable: false)
abstract class MetadataEditorState with _$MetadataEditorState {
  const factory MetadataEditorState({
    // Metadatos tal como están guardados en cada EPUB.
    @Default([]) List<EditedEpub> epubs,
    @Default(BookMetadata()) BookMetadata form,
    // Cambia cuando el formulario se reconstruye entero, para reiniciar sus campos.
    @Default(0) int revision,
    @Default(false) bool busy,
    @Default(false) bool recursive,
    MetadataEditorMessage? message,
  }) = _MetadataEditorState;
}

extension MetadataEditorStateX on MetadataEditorState {
  ({BookMetadata common, Set<MetadataField> mixed}) get _common => commonMetadata([for (final e in epubs) e.metadata]);

  Set<MetadataField> get mixed => _common.mixed;

  // Campos a los que el formulario da un valor distinto del que comparten los libros.
  Set<MetadataField> get changed => changedFields(_common.common, form);

  BookMetadata edited(EditedEpub epub) => applyFields(epub.metadata, form, changed);

  bool isDirty(EditedEpub epub) => edited(epub) != epub.metadata;
}
