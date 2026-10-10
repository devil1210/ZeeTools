import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeetools/features/plugins/domain/plugin_manifest.dart';
import 'package:zeetools/features/plugins/domain/plugin_extension.dart';
import 'package:zeetools/features/plugins/data/plugin_registry.dart';
import 'package:zeetools/features/zeepub_editorial/plugins/zeepub_catalog_extension.dart';
import 'package:zeetools/features/zeepub_editorial/plugins/zeepub_scheduler_extension.dart';
import 'package:zeetools/features/zeepub_editorial/plugins/zeepub_fansub_extension.dart';
import 'package:zeetools/features/zeepub_editorial/plugins/zeepub_uploader_extension.dart';

class _MockExtension implements ZeeToolsPluginExtension {
  @override
  String get id => 'test_plugin';

  @override
  Widget buildView(BuildContext context, PluginManifest manifest) => const Text('Plugin View');
}

void main() {
  group('PluginManifest', () {
    test('parses valid manifest correctly', () {
      const rawJson = '''{
        "id": "sample_tool",
        "name": "Herramienta de Prueba",
        "version": "1.0.0",
        "description": "Una herramienta para pruebas",
        "author": "ZeePub",
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
      expect(manifest.author, 'ZeePub');
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

      final ext = _MockExtension();
      registry.register(ext);

      expect(registry.has('test_plugin'), isTrue);
      expect(registry.get('test_plugin'), equals(ext));

      registry.unregister('test_plugin');
      expect(registry.has('test_plugin'), isFalse);
      expect(registry.get('test_plugin'), isNull);
    });

    test('registers and retrieves modular zeepub extensions', () {
      final registry = PluginRegistry();
      const extCatalog = ZeepubCatalogExtension();
      const extScheduler = ZeepubSchedulerExtension();
      const extFansub = ZeepubFansubExtension();
      const extUploader = ZeepubUploaderExtension();

      registry.register(extCatalog);
      registry.register(extScheduler);
      registry.register(extFansub);
      registry.register(extUploader);

      expect(registry.get('zeepub_catalog'), isA<ZeepubCatalogExtension>());
      expect(registry.get('zeepub_scheduler'), isA<ZeepubSchedulerExtension>());
      expect(registry.get('zeepub_fansub'), isA<ZeepubFansubExtension>());
      expect(registry.get('zeepub_uploader'), isA<ZeepubUploaderExtension>());
    });
  });
}
