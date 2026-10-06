import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '/common/utils/either.dart';
import '/features/epub_templater/domain/book_metadata.dart';
import '/features/epub_templater/domain/content_warning.dart';
import '../../data/epub_archive.dart';
import '../../data/epub_migrator_repo.dart';
import '../../domain/migration_issues.dart';
import '../../domain/migration_kind.dart';
import '../../domain/migration_project.dart';

part 'epub_migrator_state.dart';
part 'epub_migrator_cubit.freezed.dart';

class EpubMigratorCubit extends Cubit<EpubMigratorState> {
  EpubMigratorCubit(this._repo) : super(const EpubMigratorState());

  final EpubMigratorRepository _repo;
  Uint8List? _source;
  EpubArchive? _archive;

  EpubArchive? get archive => _archive;

  // Uno solo a la vez: cada libro se revisa por separado.
  Future<void> open(String path) async {
    emit(state.copyWith(busy: true));
    final result = await _repo.open(path);
    if (isClosed) return;
    result.fold(
      (error) => emit(state.copyWith(busy: false, message: EpubMigratorMessage(error, isError: true))),
      (opened) {
        _source = opened.bytes;
        _archive = opened.archive;
        emit(EpubMigratorState(project: opened.project, revision: state.revision + 1));
      },
    );
  }

  void closeBook() {
    _source = null;
    _archive = null;
    emit(EpubMigratorState(revision: state.revision + 1));
  }

  void _update(MigrationProject Function(MigrationProject p) update) {
    final project = state.project;
    if (project != null) emit(state.copyWith(project: update(project)));
  }

  void updateMetadata(BookMetadata Function(BookMetadata m) update) => _update((p) => p.copyWith(metadata: update(p.metadata)));

  void updateDoc(int index, MigrationDoc Function(MigrationDoc d) update) => _update((p) => p.copyWith(docs: [for (final (i, d) in p.docs.indexed) i == index ? update(d) : d]));

  // El tipo nuevo trae su nombre de archivo y su visibilidad en el índice si no se habían editado.
  void changeKind(int index, MigrationKind kind) => updateDoc(index, (d) {
    final followsKind = d.fileName.replaceFirst(RegExp(r'(-\d+|\d+)$'), '') == d.kind.fileName;
    final number = state.project!.docs.take(index).where((x) => x.kind == kind && !x.continuation).length + 1;
    return d.copyWith(
      kind: kind,
      matter: kind.matter ?? d.matter,
      inToc: kind.inToc,
      fileName: followsKind ? (kind.numbered ? '${kind.fileName}${number.toString().padLeft(2, '0')}' : kind.fileName) : d.fileName,
    );
  });

  void setRenames(String oldClass, List<String> classes) => _update((p) => p.copyWith(classRenames: {...p.classRenames, oldClass: classes}));

  void setCustomCss(String css) => _update((p) => p.copyWith(customCss: css));

  void setWarning(ContentWarning warning) => _update((p) => p.copyWith(warning: warning));

  void setAddNotice(bool value) => _update((p) => p.copyWith(addNotice: value));

  void setAddLogos(bool value) => _update((p) => p.copyWith(addLogos: value));

  // Devuelve el EPUB migrado, o null si quedan errores o falla la escritura.
  Future<Uint8List?> migrate() async {
    final project = state.project;
    final source = _source;
    if (project == null || source == null) return null;
    final errors = migrationIssues(project).where((i) => i.level == MigrationIssueLevel.error).toList();
    if (errors.isNotEmpty) {
      emit(state.copyWith(message: EpubMigratorMessage('Quedan ${errors.length} error${errors.length == 1 ? '' : 'es'} pendiente${errors.length == 1 ? '' : 's'}: ${errors.first.message}', isError: true)));
      return null;
    }
    emit(state.copyWith(busy: true));
    final result = await _repo.migrate(source, project);
    if (isClosed) return null;
    return result.fold(
      (error) {
        emit(state.copyWith(busy: false, message: EpubMigratorMessage(error, isError: true)));
        return null;
      },
      (epub) {
        emit(state.copyWith(busy: false, written: epub.notes));
        return epub.bytes;
      },
    );
  }

  void notify(String text, {bool isError = false}) => emit(state.copyWith(message: EpubMigratorMessage(text, isError: isError)));
}
