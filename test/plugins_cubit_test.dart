import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zeetools/features/plugins/data/plugin_repository.dart';
import 'package:zeetools/features/plugins/domain/plugin_manifest.dart';
import 'package:zeetools/features/plugins/presentation/cubit/plugins_cubit.dart';
import 'package:zeetools/features/plugins/presentation/cubit/plugins_state.dart';

import 'plugins_cubit_test.mocks.dart';

@GenerateNiceMocks([MockSpec<PluginRepository>()])
void main() {
  late MockPluginRepository mockRepo;
  late PluginsCubit cubit;

  PluginManifest createManifest(String id, {bool enabled = true}) => PluginManifest(
        id: id,
        name: 'Plugin $id',
        version: '1.0.0',
        author: 'Test',
        description: '',
        directoryPath: '/tmp/plugins/$id',
        isEnabled: enabled,
      );

  setUp(() {
    mockRepo = MockPluginRepository();
    // Por defecto, loadPlugins() retorna lista vacía
    when(mockRepo.loadPlugins()).thenAnswer((_) async => []);
    cubit = PluginsCubit(mockRepo);
  });

  tearDown(() => cubit.close());

  group('PluginsCubit.loadPlugins', () {
    test('emite estado cargado con la lista del repositorio', () async {
      final plugins = [createManifest('a'), createManifest('b')];
      when(mockRepo.loadPlugins()).thenAnswer((_) async => plugins);

      await cubit.loadPlugins();

      expect(cubit.state.plugins, equals(plugins));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
    });

    test('emite errorMessage cuando el repositorio lanza excepción', () async {
      when(mockRepo.loadPlugins()).thenThrow(Exception('disco lleno'));

      await cubit.loadPlugins();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, contains('disco lleno'));
      expect(cubit.state.plugins, isEmpty);
    });
  });

  group('PluginsCubit.togglePlugin', () {
    test('actualiza isEnabled del plugin correcto sin afectar otros', () async {
      final plugins = [createManifest('a'), createManifest('b')];
      when(mockRepo.loadPlugins()).thenAnswer((_) async => plugins);
      when(mockRepo.setPluginEnabled(any, any)).thenAnswer((_) async {});

      await cubit.loadPlugins();
      await cubit.togglePlugin('a', false);

      final result = cubit.state.plugins;
      expect(result.firstWhere((p) => p.id == 'a').isEnabled, isFalse);
      expect(result.firstWhere((p) => p.id == 'b').isEnabled, isTrue);
    });

    test('llama a setPluginEnabled en el repositorio con los valores correctos', () async {
      when(mockRepo.loadPlugins()).thenAnswer((_) async => [createManifest('a')]);
      when(mockRepo.setPluginEnabled(any, any)).thenAnswer((_) async {});

      await cubit.loadPlugins();
      await cubit.togglePlugin('a', false);

      verify(mockRepo.setPluginEnabled('a', false)).called(1);
    });
  });

  group('PluginsCubit.installFromZip', () {
    test('emite successMessage con el nombre del plugin instalado', () async {
      final installed = createManifest('nuevo');
      when(mockRepo.installPluginFromZip(any)).thenAnswer((_) async => installed);
      when(mockRepo.loadPlugins()).thenAnswer((_) async => [installed]);

      await cubit.installFromZip('/tmp/nuevo_plugin.zip');

      expect(cubit.state.successMessage, contains('Plugin nuevo'));
      expect(cubit.state.isLoading, isFalse);
    });

    test('emite errorMessage cuando el zip es inválido', () async {
      when(mockRepo.installPluginFromZip(any))
          .thenThrow(Exception('zip corrupto'));

      await cubit.installFromZip('/tmp/corrupto.zip');

      expect(cubit.state.errorMessage, contains('zip corrupto'));
      expect(cubit.state.isLoading, isFalse);
    });
  });

  group('PluginsCubit.uninstallPlugin', () {
    test('recarga la lista tras desinstalar y emite successMessage', () async {
      when(mockRepo.uninstallPlugin(any, any)).thenAnswer((_) async {});
      when(mockRepo.loadPlugins()).thenAnswer((_) async => []);

      await cubit.uninstallPlugin('a', '/tmp/plugins/a');

      expect(cubit.state.successMessage, isNotNull);
      verify(mockRepo.uninstallPlugin('a', '/tmp/plugins/a')).called(1);
    });

    test('emite errorMessage cuando la desinstalación falla', () async {
      when(mockRepo.uninstallPlugin(any, any))
          .thenThrow(Exception('permiso denegado'));

      await cubit.uninstallPlugin('a', '/tmp/plugins/a');

      expect(cubit.state.errorMessage, contains('permiso denegado'));
    });
  });

  group('PluginsState.enabledPlugins', () {
    test('filtra correctamente sólo los plugins activos', () {
      final state = PluginsState(
        plugins: [
          createManifest('a'),
          createManifest('b', enabled: false),
          createManifest('c'),
        ],
      );

      final enabled = state.enabledPlugins;
      expect(enabled.map((p) => p.id), containsAll(['a', 'c']));
      expect(enabled.any((p) => p.id == 'b'), isFalse);
    });
  });
}
