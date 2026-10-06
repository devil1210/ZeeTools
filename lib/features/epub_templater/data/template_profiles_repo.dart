import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/template_project.dart';

// Signos que Windows no admite en un nombre de archivo y su forma de ancho completo.
const _fullwidth = {'<': '＜', '>': '＞', ':': '：', '"': '＂', '/': '／', '\\': '＼', '|': '｜', '?': '？', '*': '＊'};
const _profilesKey = 'epub_templater_profiles';
const _draftKey = 'epub_templater_draft';

// Cada perfil es un archivo JSON con su nombre en [directory], para poder copiarlos
// o añadirlos a mano; el borrador en curso se guarda en las preferencias.
abstract interface class TemplateProfilesRepository {
  String get directory;
  Map<String, TemplateProject> getProfiles();
  Future<void> saveProfiles(Map<String, TemplateProject> profiles);
  TemplateProject? getDraft();
  Future<void> saveDraft(TemplateProject project);
}

class TemplateProfilesRepositoryImpl(final SharedPreferences _prefs, @override final String directory) implements TemplateProfilesRepository {
  String _fileName(String name) => '${name.split('').map((c) => _fullwidth[c] ?? c).join()}.json';

  String _profileName(String file) {
    final reverse = {for (final MapEntry(:key, :value) in _fullwidth.entries) value: key};
    return p.basenameWithoutExtension(file).split('').map((c) => reverse[c] ?? c).join();
  }

  @override
  Map<String, TemplateProject> getProfiles() {
    _migrateFromPreferences();
    final dir = Directory(directory);
    if (!dir.existsSync()) return {};
    final profiles = <String, TemplateProject>{};
    final files = dir.listSync().whereType<File>().where((f) => p.extension(f.path).toLowerCase() == '.json').toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      try {
        profiles[_profileName(file.path)] = TemplateProject.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {
        // Un archivo que no es un perfil válido se ignora.
      }
    }
    return profiles;
  }

  // Escritura síncrona: son archivos pequeños y así quedan guardados en cuanto se pide.
  @override
  Future<void> saveProfiles(Map<String, TemplateProject> profiles) async {
    final dir = Directory(directory)..createSync(recursive: true);
    final keep = {for (final name in profiles.keys) _fileName(name)};
    for (final file in dir.listSync().whereType<File>()) {
      if (p.extension(file.path).toLowerCase() == '.json' && !keep.contains(p.basename(file.path))) file.deleteSync();
    }
    const encoder = JsonEncoder.withIndent('  ');
    for (final MapEntry(key: name, value: project) in profiles.entries) {
      File(p.join(directory, _fileName(name))).writeAsStringSync(encoder.convert(project));
    }
  }

  // Los perfiles de versiones anteriores estaban en las preferencias.
  void _migrateFromPreferences() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      Directory(directory).createSync(recursive: true);
      for (final MapEntry(:key, :value) in decoded.entries) {
        final file = File(p.join(directory, _fileName(key)));
        if (!file.existsSync()) file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
      }
    } catch (_) {
      return;
    }
    _prefs.remove(_profilesKey);
  }

  @override
  TemplateProject? getDraft() {
    final raw = _prefs.getString(_draftKey);
    if (raw == null) return null;
    try {
      return TemplateProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(TemplateProject project) => _prefs.setString(_draftKey, jsonEncode(project));
}
