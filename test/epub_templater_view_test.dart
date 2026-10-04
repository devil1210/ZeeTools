import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeetools/common/process/native_tools_repo.dart';
import 'package:zeetools/common/utils/either.dart';
import 'package:zeetools/common/widgets/choice_pill.dart';
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
    profiles = TemplateProfilesRepositoryImpl(prefs);
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

  testWidgets('secciones: lista inicial, añadir y editar la seleccionada', (tester) async {
    await pumpView(tester);
    expect(find.text('Secciones (17)'), findsOneWidget);
    expect(find.text('cubierta.xhtml · Cubierta'), findsOneWidget);
    expect(find.text('El título es obligatorio.'), findsNothing);

    await tester.tap(find.byTooltip('Añadir sección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interludio').last);
    await tester.pumpAndSettle();
    expect(find.text('Secciones (18)'), findsOneWidget);
    expect(cubit.state.selected?.kind, SectionKind.interlude);

    await tester.enterText(find.widgetWithText(TextFormField, 'Subtítulo'), 'Entre capítulos');
    await tester.pump();
    expect(cubit.state.selected?.subtitle, 'Entre capítulos');
    expect(find.text('Interludio 1: Entre capítulos'), findsWidgets);
  });

  testWidgets('metadatos y perfiles: guardar, modificar y volver a cargar', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatorio'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título principal'), 'Mi novela - Volumen 01 [MN]');
    await tester.pump();
    expect(find.text('Obligatorio'), findsNothing);
    final identifier = cubit.state.project.metadata.identifier;
    expect(identifier, isNotEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Perfil de plantilla'), 'Serie A');
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar perfil'));
    await tester.pumpAndSettle();
    expect(profiles.getProfiles()['Serie A']?.metadata.identifier, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título principal'), 'Otro título');
    await tester.pump();
    await tester.tap(find.byTooltip('Cargar perfil'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Mi novela - Volumen 01 [MN]'), findsOneWidget);
    expect(cubit.state.project.metadata.identifier, allOf(isNotEmpty, isNot(identifier)));

    await tester.tap(find.byTooltip('Eliminar perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(profiles.getProfiles(), isEmpty);
  });

  testWidgets('géneros y demografía se marcan y desmarcan', (tester) async {
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoicePill, 'Drama'));
    await tester.tap(find.widgetWithText(ChoicePill, 'Acción'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.genres, ['Drama', 'Acción']);
    await tester.tap(find.widgetWithText(ChoicePill, 'Drama'));
    await tester.tap(find.widgetWithText(ChoicePill, 'Chicas/Shoujo'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.genres, ['Acción']);
    expect(cubit.state.project.metadata.subjects, ['Juvenil', 'Chicas/Shoujo', 'Acción']);
  });

  testWidgets('volumen único por defecto; escribir la serie habilita su idioma y volumen numérico', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    TextField volume() => tester.widget<TextField>(find.descendant(of: find.widgetWithText(TextFormField, 'Volumen'), matching: find.byType(TextField)));
    expect(cubit.state.project.metadata.hasSeries, isFalse);
    expect(volume().enabled, isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Serie'), 'Mitsuba’s Stories');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.hasSeries, isTrue);
    expect(volume().enabled, isTrue);

    await tester.enterText(find.widgetWithText(TextFormField, 'Volumen'), '3a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Volumen'), '3.5');
    await tester.pump();
    expect(cubit.state.project.metadata.seriesIndex, '3.5');
  });

  testWidgets('un idioma repetido entre los títulos se marca como error', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir título en otro idioma'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Idioma').at(1), 'es');
    await tester.pumpAndSettle();
    expect(find.text('Idioma repetido'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Idioma').at(1), 'ja');
    await tester.pumpAndSettle();
    expect(find.text('Idioma repetido'), findsNothing);
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

    await tester.tap(find.byTooltip('Restablecer secciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restablecer'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.sections, hasLength(initial));
  });

  test('las secciones se mantienen agrupadas por división', () {
    final sections = cubit.state.project.sections;
    final chapter = sections.firstWhere((s) => s.kind == SectionKind.chapter);
    cubit.select(chapter.key);
    cubit.addSection(SectionKind.dedication);
    final afterAdd = cubit.state.project.sections;
    final dedication = afterAdd.firstWhere((s) => s.kind == SectionKind.dedication);
    expect(afterAdd.indexOf(dedication), afterAdd.lastIndexWhere((s) => s.matter == BookMatter.front));

    cubit.moveSection(chapter.key, BookMatter.back, 0);
    final afterMove = cubit.state.project.sections;
    expect(afterMove.firstWhere((s) => s.matter == BookMatter.back).key, chapter.key);

    cubit.updateSection(chapter.key, (s) => s.copyWith(matter: BookMatter.front));
    final afterUpdate = cubit.state.project.sections;
    expect(afterUpdate.lastWhere((s) => s.matter == BookMatter.front).key, chapter.key);
    expect([for (final s in afterUpdate) s.matter.index], orderedEquals([...[for (final s in afterUpdate) s.matter.index]]..sort()));
  });

  testWidgets('fuentes: la de ejemplo se aplica a h1 y se añaden niveles', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Fuentes'));
    await tester.pumpAndSettle();
    expect(find.text('Times New Roman'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoicePill, 'h2'));
    await tester.pumpAndSettle();
    expect(cubit.state.project.fonts.single.headingLevels, [1, 2]);

    await tester.tap(find.text('Añadir fuente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Times New Roman').last);
    await tester.pumpAndSettle();
    expect(cubit.state.project.fonts, hasLength(2));
  });

  testWidgets('el nombre para ordenar aparece con el nombre y se deduce mientras no se edite', (tester) async {
    await pumpView(tester, size: const Size(1280, 3000));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nombre para ordenar'), findsNWidgets(1));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre').first, 'Nanasawa Matari');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.actors.first.fileAs, 'Matari, Nanasawa');

    await tester.enterText(find.widgetWithText(TextField, 'Nombre para ordenar').first, 'Nanasawa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre').first, 'Nanasawa Matari Sensei');
    await tester.pumpAndSettle();
    expect(cubit.state.project.metadata.actors.first.fileAs, 'Nanasawa');
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

  testWidgets('ventana estrecha: las vistas no desbordan', (tester) async {
    await pumpView(tester, size: const Size(640, 600));
    await tester.tap(find.text('Metadatos'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
