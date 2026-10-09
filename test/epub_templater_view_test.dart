import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeetools/common/process/native_tools_repo.dart';
import 'package:zeetools/common/utils/either.dart';
import 'package:zeetools/common/widgets/selection_pill.dart';
import 'package:zeetools/common/widgets/speed_dial.dart';
import 'package:zeetools/features/epub_templater/data/epub_templater_repo.dart';
import 'package:zeetools/features/epub_templater/data/system_fonts.dart';
import 'package:zeetools/features/epub_templater/domain/book_metadata.dart';
import 'package:zeetools/features/epub_templater/data/template_profiles_repo.dart';
import 'package:zeetools/features/epub_templater/domain/section_kind.dart';
import 'package:zeetools/features/epub_templater/domain/template_project.dart';
import 'package:zeetools/features/epub_templater/presentation/cubit/epub_templater_cubit.dart';
import 'package:zeetools/features/epub_templater/presentation/views/epub_templater_view.dart';
import 'package:zeetools/features/image_optimizer/data/image_optimizer_repo.dart';
import 'package:zeetools/features/image_optimizer/data/image_optimizer_settings_repo.dart';
import 'package:zeetools/features/image_optimizer/domain/image_format.dart';
import 'package:zeetools/features/image_optimizer/domain/optimization_options.dart';
import 'package:zeetools/features/image_optimizer/domain/optimization_outcome.dart';
import 'package:zeetools/features/settings/data/preferences_repo.dart';
import 'package:zeetools/features/settings/domain/date_display_format.dart';
import 'package:zeetools/inject_dependencies.dart';

class _FakeRepo implements EpubTemplaterRepository {
  Map<String, OptimizedOutcome> lastOptimized = const {};

  @override
  Future<Either<String, GeneratedEpub>> generate(TemplateProject project, {Map<String, OptimizedOutcome> optimized = const {}}) async {
    lastOptimized = optimized;
    return const Either.left('sin implementar');
  }

  @override
  Future<List<FontFace>> systemFonts() async => const [(path: 'C:/f/times.ttf', family: 'Times New Roman', style: 'Regular', weight: 400, italic: false, embeddable: true)];
}

// Cada imagen se reduce a la mitad en WebP.
class _FakeImages extends Fake implements ImageOptimizerRepository {
  final optimized = <String>[];

  @override
  Future<NativeToolset> ensureTools({void Function(String message)? onProgress}) async => const NativeToolset({});

  @override
  Future<OptimizationOutcome> optimizeFile(String path, OptimizationOptions options, NativeToolset tools) async {
    optimized.add(path);
    return OptimizationOutcome.optimized(sourceFormat: ImageFormat.png, originalSize: 200, newSize: 100, format: ImageFormat.webp, method: 'WebP', resultPath: '$path.webp');
  }

  @override
  Future<void> discardResult(OptimizationOutcome outcome) async {}
}

void main() {
  late EpubTemplaterCubit cubit;
  late _FakeRepo repo;
  late _FakeImages images;
  late TemplateProfilesRepository profiles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await getIt.reset();
    profiles = TemplateProfilesRepositoryImpl(prefs, Directory.systemTemp.createTempSync('perfiles').path);
    repo = _FakeRepo();
    images = _FakeImages();
    cubit = EpubTemplaterCubit(repo, profiles, images, ImageOptimizerSettingsRepositoryImpl(prefs));
    getIt.registerFactory<EpubTemplaterCubit>(() => cubit);
    getIt.registerLazySingleton<ValueNotifier<List<SpeedDialAction>>>(() => ValueNotifier([]));
  });

  Future<void> pumpView(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(const MaterialApp(home: EpubTemplaterView()));
    await tester.pumpAndSettle();
  }

  test('la primera ejecución guarda y carga el perfil con todos los tipos de sección', () {
    expect(profiles.getProfiles().keys, [EpubTemplaterCubit.allSectionsProfile]);
    expect({for (final s in cubit.state.project.sections) s.kind}, SectionKind.values.toSet());
    expect(cubit.state.project.guideComments, isFalse);
  });

  testWidgets('secciones: lista inicial, añadir y editar la seleccionada', (tester) async {
    await pumpView(tester);
    expect(find.text('Secciones (${SectionKind.values.length})'), findsOneWidget);
    expect(find.text('cubierta.xhtml · Cubierta'), findsOneWidget);
    expect(find.text('El título es obligatorio.'), findsNothing);

    await tester.tap(find.byTooltip('Añadir sección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interludio').last);
    await tester.pumpAndSettle();
    expect(find.text('Secciones (${SectionKind.values.length + 1})'), findsOneWidget);
    expect(cubit.state.selected?.kind, SectionKind.interlude);

    await tester.enterText(find.widgetWithText(TextFormField, 'Subtítulo'), 'Entre capítulos');
    await tester.pump();
    expect(cubit.state.selected?.subtitle, 'Entre capítulos');
    expect(find.text('Interludio 2: Entre capítulos'), findsWidgets);
  });

  testWidgets('metadatos y perfiles: guardar, modificar y volver a cargar', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatorio'), findsOneWidget);

    // El equivalente en el idioma del libro está a la vista, pero solo es obligatorio cuando hay título.
    Finder spanishRequired() => find.descendant(of: find.widgetWithText(TextFormField, 'Título en español'), matching: find.text('Obligatorio'));
    expect(spanishRequired(), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en inglés'), 'My Novel - Volumen 01 [MN]');
    await tester.pump();
    expect(spanishRequired(), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en español'), 'Mi novela - Volumen 01');
    await tester.pump();
    expect(find.text('Obligatorio'), findsNothing);
    final identifier = cubit.state.project.metadata.identifier;
    expect(identifier, isNotEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Perfil de plantilla'), 'Serie A');
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar perfil'));
    await tester.pumpAndSettle();
    expect(profiles.getProfiles()['Serie A']?.metadata.identifier, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título en inglés'), 'Otro título');
    await tester.pump();
    await tester.tap(find.byTooltip('Cargar perfil'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'My Novel - Volumen 01 [MN]'), findsOneWidget);
    expect(cubit.state.project.metadata.identifier, allOf(isNotEmpty, isNot(identifier)));

    await tester.tap(find.byTooltip('Eliminar perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(profiles.getProfiles().keys, [EpubTemplaterCubit.allSectionsProfile]);
  });

  testWidgets('el campo de perfil vacío despliega todos los perfiles al enfocarlo', (tester) async {
    await pumpView(tester);
    expect(find.widgetWithText(MenuItemButton, EpubTemplaterCubit.allSectionsProfile), findsNothing);
    await tester.tap(find.widgetWithText(TextField, 'Perfil de plantilla'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, EpubTemplaterCubit.allSectionsProfile));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, EpubTemplaterCubit.allSectionsProfile), findsOneWidget);
    expect(find.byTooltip('Cargar perfil'), findsOneWidget);
  });

  testWidgets('géneros y demografía se marcan y desmarcan', (tester) async {
    await pumpView(tester, size: const Size(1280, 6000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SelectionPill, 'Drama'));
    await tester.tap(find.widgetWithText(SelectionPill, 'Acción'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.genres, ['Drama', 'Acción']);
    await tester.tap(find.widgetWithText(SelectionPill, 'Drama'));
    await tester.tap(find.widgetWithText(SelectionPill, 'Chicas/Shoujo'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.genres, ['Acción']);
    expect(cubit.state.project.metadata.subjects, ['Juvenil', 'Chicas/Shoujo', 'Acción']);
  });

  testWidgets('sin serie no hay volumen; escribir la serie habilita su volumen numérico', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    TextField volume() => tester.widget<TextField>(find.descendant(of: find.widgetWithText(TextFormField, 'Volumen'), matching: find.byType(TextField)));
    expect(cubit.state.project.metadata.hasSeries, isFalse);
    expect(volume().enabled, isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Serie en inglés'), 'Mitsuba’s Stories');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.hasSeries, isTrue);
    expect(volume().enabled, isTrue);

    await tester.enterText(find.widgetWithText(TextFormField, 'Volumen'), '3a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Volumen'), '3.5');
    await tester.pump();
    expect(cubit.state.project.metadata.seriesIndex, '3.5');
  });

  testWidgets('el idioma original añade el título y la serie romanizados y en su escritura', (tester) async {
    await pumpView(tester, size: const Size(1280, 2000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en inglés'), 'Mitsuba’s Story');
    await tester.enterText(find.widgetWithText(TextFormField, 'Serie en inglés'), 'Mitsuba’s Stories');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en español'), 'La historia de Mitsuba');
    await tester.pumpAndSettle();
    // Al restablecer, la obra está escrita en japonés.
    expect(find.widgetWithText(TextFormField, 'Título en romaji'), findsOneWidget);

    await tester.tap(find.text('Japonés').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inglés').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Título en romaji'), findsNothing);

    await tester.tap(find.text('Inglés').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japonés').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en japonés'), '三葉の物語');
    await tester.enterText(find.widgetWithText(TextFormField, 'Título en romaji'), 'Mitsuba no Monogatari');
    await tester.enterText(find.widgetWithText(TextFormField, 'Serie en romaji'), 'Mitsuba no Monogatari');
    await tester.pumpAndSettle();
    final m = cubit.state.project.metadata;
    expect(m.titleLang, 'en');
    expect([for (final t in m.altTitles) t.lang], ['es', 'ja-Latn', 'ja']);
    expect([for (final t in m.altSeries) (t.lang, t.text)], [('ja-Latn', 'Mitsuba no Monogatari'), ('ja', '')]);

    await tester.tap(find.text('Japonés').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coreano').last);
    await tester.pumpAndSettle();
    expect([for (final t in cubit.state.project.metadata.altTitles) (t.lang, t.text)], [('es', 'La historia de Mitsuba'), ('ko-Latn', 'Mitsuba no Monogatari'), ('ko', '三葉の物語')]);
    expect(find.widgetWithText(TextFormField, 'Título en romanización'), findsOneWidget);

    // Una obra escrita en español lleva el título principal en español y el inglés pasa a equivalente opcional.
    await tester.tap(find.text('Coreano').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    final spanish = cubit.state.project.metadata;
    expect((spanish.title, spanish.titleLang), ('La historia de Mitsuba', 'es'));
    expect([for (final t in spanish.altTitles) (t.lang, t.text)], [('en', 'Mitsuba’s Story')]);
    expect(find.widgetWithText(TextFormField, 'Título en español'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Título en inglés'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(TextFormField, 'Título en inglés'), matching: find.text('Obligatorio')), findsNothing);
  });

  testWidgets('eliminar una sección pide confirmación y restablecer recupera las iniciales', (tester) async {
    await pumpView(tester);
    final initial = cubit.state.project.sections.length;
    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.sections, hasLength(initial));

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.sections, hasLength(initial - 1));

    await tester.tap(find.byTooltip('Restablecer todo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restablecer'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.sections, hasLength(TemplateProject.initial().sections.length));
  });

  test('las secciones se mantienen agrupadas por división', () {
    final sections = cubit.state.project.sections;
    final chapter = sections.firstWhere((s) => s.kind == SectionKind.chapter);
    cubit.select(chapter.key);
    cubit.addSection(SectionKind.dedication);
    final afterAdd = cubit.state.project.sections;
    final dedication = afterAdd.lastWhere((s) => s.kind == SectionKind.dedication);
    expect(afterAdd.indexOf(dedication), afterAdd.lastIndexWhere((s) => s.matter == BookMatter.front));

    cubit.moveSection(chapter.key, BookMatter.back, 0);
    final afterMove = cubit.state.project.sections;
    expect(afterMove.firstWhere((s) => s.matter == BookMatter.back).key, chapter.key);

    cubit.updateSection(chapter.key, (s) => s.copyWith(matter: BookMatter.front));
    final afterUpdate = cubit.state.project.sections;
    expect(afterUpdate.lastWhere((s) => s.matter == BookMatter.front).key, chapter.key);
    expect(
      [for (final s in afterUpdate) s.matter.index],
      orderedEquals(
        [
          ...[for (final s in afterUpdate) s.matter.index],
        ]..sort(),
      ),
    );
  });

  testWidgets('fuentes: la de ejemplo se aplica a h1 y se añaden niveles', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Fuentes y CSS'));
    await tester.pumpAndSettle();
    expect(find.text('Times New Roman'), findsOneWidget);

    await tester.tap(find.widgetWithText(SelectionPill, 'h2'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.fonts.single.headingLevels, [1, 2]);

    await tester.tap(find.text('Añadir fuente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Times New Roman').last);
    await tester.pumpAndSettle();
    expect(cubit.state.project.fonts, hasLength(2));
  });

  testWidgets('el nombre para ordenar se habilita con el nombre y se deduce mientras no se edite', (tester) async {
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    final actors = cubit.state.project.metadata.actors;
    expect([for (final field in tester.widgetList<TextField>(find.widgetWithText(TextField, 'Nombre para ordenar'))) field.enabled], [for (final a in actors) a.name.isNotEmpty]);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre en romaji').first, 'Nanasawa Matari');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.actors.first.fileAs, 'Matari, Nanasawa');

    await tester.enterText(find.widgetWithText(TextField, 'Nombre para ordenar').first, 'Nanasawa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre en romaji').first, 'Nanasawa Matari Sensei');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.actors.first.fileAs, 'Nanasawa');
  });

  testWidgets('el nombre original solo se pide a quien tiene un nombre en escritura propia', (tester) async {
    await pumpView(tester, size: const Size(1280, 4000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    // Los creadores de una obra japonesa tienen nombre en japonés; los colaboradores, en alfabeto latino.
    final creators = cubit.state.project.metadata.actors.where((a) => a.isCreator).length;
    expect(find.widgetWithText(TextFormField, 'Nombre en japonés'), findsNWidgets(creators));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre en japonés').first, '七沢またり');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.actors.first.scriptName?.text, '七沢またり');

    await tester.tap(find.descendant(of: find.widgetWithText(InputDecorator, 'Idioma del nombre').first, matching: find.text('Japonés')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alfabeto latino').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Nombre en japonés'), findsNWidgets(creators - 1));
    expect(cubit.state.project.metadata.actors.first.altNames, isEmpty);
  });

  testWidgets('las líneas en blanco de los créditos van entre personas: se quitan, se añaden y se arrastran', (tester) async {
    await pumpView(tester, size: const Size(1280, 4000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    List<bool> separated() => [for (final a in cubit.state.project.metadata.actors) a.separated];
    final initial = separated();
    expect(find.widgetWithText(InputChip, 'Línea en blanco'), findsNWidgets(maxCreditSeparators));
    expect(find.widgetWithText(TextButton, 'Línea en blanco'), findsNothing);

    await tester.tap(find.byTooltip('Quitar la línea en blanco').first);
    await tester.pumpAndSettle();
    final first = initial.indexOf(true);
    expect(separated()[first], isFalse);

    await tester.tap(find.widgetWithText(TextButton, 'Línea en blanco').first);
    await tester.pumpAndSettle();
    expect(separated().first, isTrue);

    // Con las dos en uso, una se mueve arrastrándola al último hueco.
    final gaps = find.byWidgetPredicate((w) => w is DragTarget<int>);
    final last = cubit.state.project.metadata.actors.length - 2;
    await tester.dragFrom(tester.getCenter(find.widgetWithText(InputChip, 'Línea en blanco').first), tester.getCenter(gaps.at(last)) - tester.getCenter(find.widgetWithText(InputChip, 'Línea en blanco').first));
    await tester.pumpAndSettle();
    expect(separated().first, isFalse);
    expect(separated()[last], isTrue);
  });

  testWidgets('el ojo de cada sección la quita o añade al índice', (tester) async {
    await pumpView(tester);
    final cover = cubit.state.project.sections.first;
    expect(cover.inToc, isTrue);
    await tester.tap(find.byTooltip('Quitar del índice').first);
    await tester.pumpAndSettle();
    expect(cubit.state.project.sections.first.inToc, isFalse);
  });

  testWidgets('la fecha se elige desde el calendario desplegado', (tester) async {
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fecha de publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Fecha de publicación'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(cubit.state.project.metadata.date, endsWith('-15'));
  });

  testWidgets('la fecha se muestra con el formato elegido, que se guarda como preferencia de la aplicación', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    getIt.registerLazySingleton<PreferencesRepository>(() => PreferencesRepositoryImpl(prefs));
    cubit.updateMetadata((m) => m.copyWith(date: '2013-11-22T00:00:00Z'));
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    expect(find.text('2013-11-22'), findsOneWidget);

    await tester.ensureVisible(find.text('Fecha de publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Fecha de publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YYYY-MM-DD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DD/MM/YYYY').last);
    await tester.pumpAndSettle();
    expect(find.text('22/11/2013'), findsOneWidget);
    expect(getIt<PreferencesRepository>().getDateFormat(), DateDisplayFormat.dayMonthSlash);
    expect(cubit.state.project.metadata.date, '2013-11-22T00:00:00Z');
  });

  testWidgets('el equivalente obligatorio del título es el del idioma del libro', (tester) async {
    cubit.updateMetadata((m) => m.copyWith(title: 'Wandering Witch', language: 'ja'));
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Título en japonés'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Título en romaji'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Título en español'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(TextFormField, 'Título en japonés'), matching: find.text('Obligatorio')), findsOneWidget);
    expect(find.text('Japonés'), findsWidgets);

    // En un libro en inglés el japonés sigue como idioma original, pero ya no es obligatorio.
    cubit.updateMetadata((m) => m.copyWith(language: 'en'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Título en japonés'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(TextFormField, 'Título en japonés'), matching: find.text('Obligatorio')), findsNothing);
  });

  test('las imágenes se optimizan una vez y el resultado llega a la generación', () async {
    final cover = cubit.state.project.sections.first;
    cubit.updateSection(cover.key, (s) => s.copyWith(images: ['C:/img/portada.png']));
    await cubit.optimizeImages();
    await cubit.optimizeImages();
    expect(images.optimized, ['C:/img/portada.png']);
    await cubit.generate();
    expect(repo.lastOptimized['C:/img/portada.png']?.format, ImageFormat.webp);

    await cubit.setQualityMode(QualityMode.visuallyLossless);
    expect(cubit.state.imageJobs, isEmpty);
  });

  testWidgets('el índice lateral desplaza el formulario sin cambiar de pestaña', (tester) async {
    await pumpView(tester, size: const Size(1600, 900));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Clasificación'));
    await tester.pumpAndSettle();
    expect(DefaultTabController.of(tester.element(find.byType(TabBarView))).index, 1);
    expect(tester.getTopLeft(find.widgetWithText(Card, 'Identificación')).dy, lessThan(0));
    expect(tester.getTopLeft(find.widgetWithText(Card, 'Clasificación')).dy, inInclusiveRange(0, 900));
  });

  testWidgets('ventana estrecha: las vistas no desbordan', (tester) async {
    await pumpView(tester, size: const Size(640, 600));
    for (final tab in ['Metadatos', 'Imágenes', 'Fuentes y CSS']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
