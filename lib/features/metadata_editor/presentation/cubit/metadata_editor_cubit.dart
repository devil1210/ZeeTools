import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '/common/utils/either.dart';
import '/common/utils/uuid_v7.dart';
import '/features/epub_templater/domain/book_metadata.dart';
import '/features/epub_templater/domain/metadata_field.dart';
import '../../data/epub_metadata_repo.dart';

part 'metadata_editor_cubit.freezed.dart';
part 'metadata_editor_state.dart';

class MetadataEditorCubit extends Cubit<MetadataEditorState> {
  MetadataEditorCubit(this._repo) : super(const MetadataEditorState());

  final EpubMetadataRepository _repo;

  void setRecursive(bool value) => emit(state.copyWith(recursive: value));

  Future<void> open(List<String> paths) async {
    final known = {for (final e in state.epubs) e.path};
    final found = _repo.discover(paths, recursive: state.recursive).where((path) => !known.contains(path)).toSet();
    if (found.isEmpty) {
      emit(state.copyWith(message: (text: 'No se encontraron EPUBs nuevos.', isError: false)));
      return;
    }
    emit(state.copyWith(busy: true));
    final added = <EditedEpub>[];
    final errors = <String>[];
    for (final path in found) {
      switch (await _repo.load(path)) {
        case Right(value: final metadata):
          added.add((path: path, metadata: metadata));
        case Left(value: final error):
          errors.add(error);
      }
    }
    _replaceEpubs([...state.epubs, ...added], message: errors.isEmpty ? null : (text: errors.join('\n'), isError: true));
  }

  void remove(String path) {
    _repo.unload(path);
    _replaceEpubs(state.epubs.where((e) => e.path != path).toList());
  }

  void closeAll() {
    for (final e in state.epubs) {
      _repo.unload(e.path);
    }
    _replaceEpubs(const []);
  }

  void updateForm(BookMetadata Function(BookMetadata m) f) => emit(state.copyWith(form: f(state.form)));

  // Solo con un libro: con varios cada uno conserva su identificador.
  void regenerateIdentifier() => updateForm((m) => m.copyWith(identifier: uuidV7()));

  void discardChanges() => _replaceEpubs(state.epubs, keepChanges: false);

  Future<void> save() async {
    emit(state.copyWith(busy: true));
    final epubs = <EditedEpub>[];
    final errors = <String>[];
    var saved = 0;
    for (final epub in state.epubs) {
      var edited = state.edited(epub);
      if (edited == epub.metadata) {
        epubs.add(epub);
        continue;
      }
      if (edited.identifier.trim().isEmpty) edited = edited.copyWith(identifier: uuidV7());
      switch (await _repo.save(epub.path, edited)) {
        case Right():
          epubs.add((path: epub.path, metadata: edited));
          saved++;
        case Left(value: final error):
          epubs.add(epub);
          errors.add(error);
      }
    }
    _replaceEpubs(
      epubs,
      message: errors.isEmpty ? (text: 'Se guardaron $saved EPUB${saved == 1 ? '' : 's'}.', isError: false) : (text: errors.join('\n'), isError: true),
    );
  }

  // Los libros se muestran por nombre de archivo, que en una serie sigue el
  // orden de los volúmenes. Los cambios pendientes se aplican también a los nuevos.
  void _replaceEpubs(List<EditedEpub> epubs, {bool keepChanges = true, MetadataEditorMessage? message}) {
    final sorted = [...epubs]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    final common = commonMetadata([for (final e in sorted) e.metadata]).common;
    emit(
      state.copyWith(
        epubs: sorted,
        form: keepChanges ? applyFields(common, state.form, state.changed) : common,
        revision: state.revision + 1,
        busy: false,
        message: message,
      ),
    );
  }
}
