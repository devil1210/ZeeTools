import 'dart:io';

import 'package:path/path.dart' as p;

import '/common/epub/models/epub_failure.dart';
import '/common/epub/repositories/epub_repo.dart';
import '/common/utils/either.dart';
import '/features/epub_templater/data/opf_metadata.dart';
import '/features/epub_templater/domain/book_metadata.dart';

abstract interface class EpubMetadataRepository {
  // EPUBs indicados directamente o dentro de las carpetas de [paths].
  List<String> discover(List<String> paths, {bool recursive = false});
  Future<Either<String, BookMetadata>> load(String path);
  Future<Either<String, void>> save(String path, BookMetadata metadata);
  void unload(String path);
}

class EpubMetadataRepositoryImpl implements EpubMetadataRepository {
  EpubMetadataRepositoryImpl(this._epubs);

  final EpubRepository _epubs;

  @override
  List<String> discover(List<String> paths, {bool recursive = false}) => [
    for (final path in paths)
      if (FileSystemEntity.isDirectorySync(path))
        ..._epubs.discoverEpubs(path, recursive: recursive).getOrElse((_) => const [])
      else if (p.extension(path).toLowerCase() == '.epub')
        path,
  ];

  @override
  Future<Either<String, BookMetadata>> load(String path) async {
    if (await _epubs.loadEpub(path, include: (_) => false) case Left(value: final failure)) return Either.left(_describe(path, failure));
    final opf = await _readOpf(path);
    return opf.fold(Either.left, (text) {
      try {
        return Either.right(OpfMetadata(text).read());
      } catch (e) {
        return Either.left('${p.basename(path)}: el OPF no es XML válido ($e)');
      }
    });
  }

  @override
  Future<Either<String, void>> save(String path, BookMetadata metadata) async {
    final opf = await _readOpf(path);
    if (opf case Left(:final value)) return Either.left(value);
    final text = opf.getOrElse((_) => '');
    if (await _epubs.writeTextFile(path, _epubs.opfPath(path)!, OpfMetadata(text).write(text, metadata)) case Left(value: final failure)) {
      return Either.left(_describe(path, failure));
    }
    if (await _epubs.saveEpub(path) case Left(value: final failure)) return Either.left(_describe(path, failure));
    return const Either.right(null);
  }

  @override
  void unload(String path) => _epubs.unloadEpub(path);

  Future<Either<String, String>> _readOpf(String path) async {
    final opfPath = _epubs.opfPath(path);
    if (opfPath == null) return Either.left('${p.basename(path)}: no se encontró el OPF');
    final text = await _epubs.readTextFile(path, opfPath);
    return text.fold((failure) => Either.left(_describe(path, failure)), Either.right);
  }

  String _describe(String path, EpubFailure failure) => '${p.basename(path)}: ${failure.when(
    fileNotFound: (missing) => 'no se encontró $missing',
    invalidContainer: (details) => 'no es un ZIP válido ($details)',
    containerXmlMissing: () => 'falta META-INF/container.xml',
    opfMissing: (opfPath) => 'falta el OPF $opfPath',
    encodingError: (archivePath, _) => '$archivePath no está en UTF-8',
    writeError: (details) => 'no se pudo escribir ($details)',
    invalidRegex: (_, details) => details,
    unexpected: (details) => details,
  )}';
}
