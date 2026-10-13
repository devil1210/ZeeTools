import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/plugin_manifest.dart';

class PluginRepository {
  final SharedPreferences _prefs;
  Directory? _cachedPluginsDir;

  PluginRepository(this._prefs);

  Future<Directory> getPluginsDirectory() async {
    if (_cachedPluginsDir != null) return _cachedPluginsDir!;

    try {
      // 1. Modo portable: revisar si existe carpeta 'plugins' junto al ejecutable
      final exeDir = File(Platform.resolvedExecutable).parent;
      final portablePlugins = Directory(p.join(exeDir.path, 'plugins'));
      if (await portablePlugins.exists()) {
        _cachedPluginsDir = portablePlugins;
        return portablePlugins;
      }
    } catch (_) {}

    // 2. Ruta estándar de soporte de la aplicación
    final appSupport = await getApplicationSupportDirectory();
    final pluginsDir = Directory(p.join(appSupport.path, 'plugins'));
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
    }
    _cachedPluginsDir = pluginsDir;
    return pluginsDir;
  }

  Future<List<PluginManifest>> loadPlugins() async {
    final dir = await getPluginsDirectory();
    final List<PluginManifest> list = [];

    if (!await dir.exists()) return list;

    final entities = dir.listSync();
    for (final entity in entities) {
      if (entity is Directory) {
        final manifestFile = File(p.join(entity.path, 'manifest.json'));
        if (await manifestFile.exists()) {
          try {
            final jsonStr = await manifestFile.readAsString();
            final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
            final id = jsonMap['id'] as String? ?? p.basename(entity.path);
            final isEnabled = _prefs.getBool('plugin_${id}_enabled') ?? true;
            list.add(PluginManifest.fromJson(jsonMap, entity.path, isEnabled: isEnabled));
          } catch (_) {}
        }
      }
    }

    return list;
  }

  Future<PluginManifest> installPluginFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('El archivo ZIP no existe: $zipPath');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Buscar manifest.json en el archivo
    ArchiveFile? manifestArchiveFile;
    String prefixToRemove = '';

    for (final file in archive) {
      if (file.name.endsWith('manifest.json')) {
        manifestArchiveFile = file;
        final parts = p.split(file.name);
        if (parts.length > 1) {
          prefixToRemove = '${parts.sublist(0, parts.length - 1).join('/')}/';
        }
        break;
      }
    }

    if (manifestArchiveFile == null) {
      throw Exception('El archivo ZIP no contiene un manifest.json válido');
    }

    final manifestContent = utf8.decode(manifestArchiveFile.content as List<int>);
    final manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
    final pluginId = manifestMap['id'] as String? ?? 'plugin_${DateTime.now().millisecondsSinceEpoch}';

    final pluginsDir = await getPluginsDirectory();
    final targetDir = Directory(p.join(pluginsDir.path, pluginId));

    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    // Extraer archivos
    for (final file in archive) {
      if (file.isFile) {
        var relPath = file.name;
        if (prefixToRemove.isNotEmpty && relPath.startsWith(prefixToRemove)) {
          relPath = relPath.substring(prefixToRemove.length);
        }
        if (relPath.isEmpty) continue;

        final outFile = File(p.join(targetDir.path, relPath));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    await _prefs.setBool('plugin_${pluginId}_enabled', true);
    return PluginManifest.fromJson(manifestMap, targetDir.path, isEnabled: true);
  }

  Future<void> setPluginEnabled(String id, bool enabled) async {
    await _prefs.setBool('plugin_${id}_enabled', enabled);
  }

  Future<void> uninstallPlugin(String id, String directoryPath) async {
    final dir = Directory(directoryPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _prefs.remove('plugin_${id}_enabled');
  }

  Future<void> openPluginsDirectory() async {
    final dir = await getPluginsDirectory();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
    }
  }
}
