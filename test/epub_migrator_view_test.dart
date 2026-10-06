import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/common/utils/either.dart';
import 'package:zeetools/common/widgets/speed_dial.dart';
import 'package:zeetools/features/epub_migrator/data/epub_archive.dart';
import 'package:zeetools/features/epub_migrator/data/epub_migrator_repo.dart';
import 'package:zeetools/features/epub_migrator/data/migration_analyzer.dart';
import 'package:zeetools/features/epub_migrator/data/migration_writer.dart';
import 'package:zeetools/features/epub_migrator/domain/migration_kind.dart';
import 'package:zeetools/features/epub_migrator/domain/migration_project.dart';
import 'package:zeetools/features/epub_migrator/presentation/cubit/epub_migrator_cubit.dart';
import 'package:zeetools/features/epub_migrator/presentation/views/epub_migrator_view.dart';
import 'package:zeetools/inject_dependencies.dart';

import 'helpers/old_template_epub.dart';

class _FakeRepo implements EpubMigratorRepository {
  MigrationProject? migrated;

  @override
  Future<Either<String, OpenedEpub>> open(String path) async {
    final bytes = oldTemplateEpub();
    final project = analyzeEpub(path, EpubArchive.decode(bytes), templateCss: File('assets/epub_templater/style.css').readAsStringSync());
    return Either.right((bytes: bytes, archive: EpubArchive.decode(bytes), project: project));
  }

  @override
  Future<Either<String, MigratedEpub>> migrate(Uint8List source, MigrationProject project) async {
    migrated = project;
    return Either.right((bytes: Uint8List(0), notes: const <MigrationIssue>[]));
  }
}

void main() {
  late _FakeRepo repo;
  late EpubMigratorCubit cubit;

  setUp(() async {
    await getIt.reset();
    repo = _FakeRepo();
    cubit = EpubMigratorCubit(repo);
    getIt.registerFactory<EpubMigratorCubit>(() => cubit);
    getIt.registerLazySingleton<ValueNotifier<List<SpeedDialAction>>>(() => ValueNotifier([]));
  });

  testWidgets('muestra los archivos, las secciones propuestas y lo pendiente', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(const MaterialApp(home: EpubMigratorView()));
    expect(find.text('Abrir EPUB…'), findsOneWidget);

    await cubit.open('C:/libros/mi novela.epub');
    await tester.pumpAndSettle();
    expect(find.text('Migrar · mi novela.epub'), findsOneWidget);
    expect(find.text('Section0001-2.xhtml'), findsWidgets);
    expect(find.text('↳ se une a capitulo01.xhtml'), findsOneWidget);
    expect(find.text('Se une a «Capítulo 1: El inicio» (capitulo01.xhtml) con un salto de página.'), findsOneWidget);

    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('El título principal está en «es»: escríbelo en inglés.'), findsOneWidget);

    expect(await cubit.migrate(), isNull);
    expect(repo.migrated, isNull);
    cubit.updateMetadata((m) => m.copyWith(title: 'My Novel - Volumen 01 [MN]', titleLang: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('El título principal está en «es»: escríbelo en inglés.'), findsNothing);
    expect(await cubit.migrate(), isNotNull);
    expect(repo.migrated?.metadata.title, 'My Novel - Volumen 01 [MN]');
  });

  testWidgets('cambiar el tipo de una sección propone su nombre de archivo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(const MaterialApp(home: EpubMigratorView()));
    await cubit.open('C:/libros/mi novela.epub');
    await tester.pumpAndSettle();

    cubit.changeKind(1, MigrationKind.prologue);
    await tester.pumpAndSettle();
    final doc = cubit.state.project!.docs[1];
    expect((doc.kind, doc.fileName, doc.matter), (MigrationKind.prologue, 'prologo', doc.matter));
    expect(find.widgetWithText(TextFormField, 'prologo'), findsOneWidget);
  });

  testWidgets('ventana estrecha: las pestañas no desbordan', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 700));
    await tester.pumpWidget(const MaterialApp(home: EpubMigratorView()));
    await cubit.open('C:/libros/mi novela.epub');
    await tester.pumpAndSettle();
    for (final tab in ['Secciones', 'Metadatos', 'Estilos', 'Pendientes']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
