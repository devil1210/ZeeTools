import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/common/utils/either.dart';
import 'package:zeetools/common/widgets/speed_dial.dart';
import 'package:zeetools/features/epub_templater/domain/book_metadata.dart';
import 'package:zeetools/features/epub_templater/presentation/views/widgets/metadata_form.dart';
import 'package:zeetools/features/metadata_editor/data/epub_metadata_repo.dart';
import 'package:zeetools/features/metadata_editor/presentation/cubit/metadata_editor_cubit.dart';
import 'package:zeetools/features/metadata_editor/presentation/views/metadata_editor_view.dart';
import 'package:zeetools/inject_dependencies.dart';

class _FakeRepo implements EpubMetadataRepository {
  final books = {
    'C:/s/v01.epub': const BookMetadata(identifier: 'a', title: 'Serie - Volumen 01', series: 'Serie', seriesIndex: '1'),
    'C:/s/v02.epub': const BookMetadata(identifier: 'b', title: 'Serie - Volumen 02', series: 'Serie', seriesIndex: '2', date: '0101-01-01T00:00:00+00:00'),
  };
  final saved = <String, BookMetadata>{};

  @override
  List<String> discover(List<String> paths, {bool recursive = false}) => paths;

  @override
  Future<Either<String, BookMetadata>> load(String path) async => Either.right(books[path]!);

  @override
  Future<Either<String, void>> save(String path, BookMetadata metadata) async {
    saved[path] = metadata;
    return const Either.right(null);
  }

  @override
  void unload(String path) {}
}

void main() {
  late _FakeRepo repo;
  late MetadataEditorCubit cubit;

  setUp(() async {
    await getIt.reset();
    repo = _FakeRepo();
    cubit = MetadataEditorCubit(repo);
    getIt.registerFactory<MetadataEditorCubit>(() => cubit);
    getIt.registerLazySingleton<ValueNotifier<List<SpeedDialAction>>>(() => ValueNotifier([]));
  });

  testWidgets('con varios EPUBs muestra la lista y aplica a todos solo los campos editados', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(const MaterialApp(home: MetadataEditorView()));
    await cubit.open(['C:/s/v01.epub']);
    await tester.pumpAndSettle();
    expect(find.text('EPUBs (1)'), findsNothing);
    expect(find.text('Serie - Volumen 01'), findsOneWidget);

    await cubit.open(['C:/s/v02.epub']);
    await tester.pumpAndSettle();
    expect(find.text('EPUBs (2)'), findsOneWidget);
    expect(find.text('Varios valores'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Serie').first, 'Serie nueva');
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar 2 EPUBs'));
    await tester.pumpAndSettle();
    expect(repo.saved['C:/s/v01.epub'], repo.books['C:/s/v01.epub']!.copyWith(series: 'Serie nueva'));
    expect(repo.saved['C:/s/v02.epub'], repo.books['C:/s/v02.epub']!.copyWith(series: 'Serie nueva'));
  });

  testWidgets('al quitar libros hasta dejar uno, el calendario abre aunque su fecha esté fuera de rango', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(const MaterialApp(home: MetadataEditorView()));
    await cubit.open(['C:/s/v01.epub', 'C:/s/v02.epub']);
    await tester.pumpAndSettle();
    expect(find.text('Varios valores'), findsWidgets);

    cubit.remove('C:/s/v01.epub');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Fecha de publicación'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fecha de publicación'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('señala con la etiqueta elevada los campos que difieren y los que ningún libro tiene', (tester) async {
    repo.books
      ..['C:/s/v01.epub'] = const BookMetadata(identifier: 'a', title: 'Uno', language: 'es', titleLang: 'ja-Latn', bookType: 'Novela Ligera')
      ..['C:/s/v02.epub'] = const BookMetadata(identifier: 'b', title: 'Dos', language: 'en', bookType: 'Novela Web');
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    await tester.pumpWidget(const MaterialApp(home: MetadataEditorView()));
    await cubit.open(['C:/s/v01.epub', 'C:/s/v02.epub']);
    await tester.pumpAndSettle();

    InputDecoration decorationOf(String label) => tester.widgetList<InputDecorator>(find.byType(InputDecorator)).firstWhere((d) => d.decoration.labelText == label).decoration;
    for (final (label, hint) in [('Idioma del libro', mixedValuesHint), ('Tipo', mixedValuesHint), ('Serie en inglés', noValueHint), ('Fecha de publicación', noValueHint), ('Título en inglés', mixedValuesHint)]) {
      final decoration = decorationOf(label);
      expect((label, decoration.hintText), (label, hint));
      expect((label, decoration.floatingLabelBehavior), (label, FloatingLabelBehavior.always));
    }
    expect(find.text('Editorial o grupo · $noValueHint'), findsOneWidget);
  });
}
