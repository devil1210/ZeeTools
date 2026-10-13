import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/features/plugins/domain/plugin_manifest.dart';
import 'package:zeetools/features/plugins/domain/plugin_extension.dart';
import 'package:zeetools/features/plugins/data/plugin_registry.dart';

class _MockExtension implements ZeeToolsPluginExtension {
  final String _id;
  const _MockExtension([this._id = 'test_plugin']);

  @override
  String get id => _id;

  @override
  Widget buildView(BuildContext context, PluginManifest manifest) => Text('Plugin View $_id');
}

void main() {
  group('PluginManifest', () {
    test('parses valid manifest correctly', () {
      const rawJson = '''{
        "id": "sample_tool",
        "name": "Herramienta de Prueba",
        "version": "1.0.0",
        "description": "Una herramienta para pruebas",
        "author": "Comunidad",
        "icon": "book",
        "entry_point": "lib/main.dart"
      }''';

      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final manifest = PluginManifest.fromJson(
        map,
        '/plugins/sample_tool',
        isEnabled: true,
      );

      expect(manifest.id, 'sample_tool');
      expect(manifest.name, 'Herramienta de Prueba');
      expect(manifest.version, '1.0.0');
      expect(manifest.author, 'Comunidad');
      expect(manifest.iconData, Icons.book_rounded);
      expect(manifest.entryPoint, 'lib/main.dart');
      expect(manifest.isEnabled, isTrue);
    });

    test('falls back gracefully on empty or missing fields', () {
      final manifest = PluginManifest.fromJson(
        {},
        '/plugins/empty',
        isEnabled: false,
      );

      expect(manifest.name, 'Complemento sin nombre');
      expect(manifest.version, '1.0.0');
      expect(manifest.iconData, Icons.extension_rounded);
      expect(manifest.isEnabled, isFalse);
    });

    test('resolves calendar, groups and cloud_upload icons correctly', () {
      final mCalendar = PluginManifest.fromJson(const {'icon': 'calendar_month'}, '/p', isEnabled: true);
      final mGroups = PluginManifest.fromJson(const {'icon': 'groups'}, '/p', isEnabled: true);
      final mUpload = PluginManifest.fromJson(const {'icon': 'cloud_upload'}, '/p', isEnabled: true);

      expect(mCalendar.iconData, equals(Icons.calendar_month_rounded));
      expect(mGroups.iconData, equals(Icons.groups_rounded));
      expect(mUpload.iconData, equals(Icons.cloud_upload_rounded));
    });
  });

  group('PluginRegistry', () {
    test('registers and retrieves extensions', () {
      final registry = PluginRegistry();
      expect(registry.has('test_plugin'), isFalse);

      const ext = _MockExtension();
      registry.register(ext);

      expect(registry.has('test_plugin'), isTrue);
      expect(registry.get('test_plugin'), equals(ext));

      registry.unregister('test_plugin');
      expect(registry.has('test_plugin'), isFalse);
      expect(registry.get('test_plugin'), isNull);
    });

    test('registers and retrieves multiple modular extensions', () {
      final registry = PluginRegistry();
      const extA = _MockExtension('tool_a');
      const extB = _MockExtension('tool_b');
      const extC = _MockExtension('tool_c');

      registry.register(extA);
      registry.register(extB);
      registry.register(extC);

      expect(registry.get('tool_a'), equals(extA));
      expect(registry.get('tool_b'), equals(extB));
      expect(registry.get('tool_c'), equals(extC));
    });
  });
}
