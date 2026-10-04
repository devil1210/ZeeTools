import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/template_project.dart';

// Perfiles con nombre y el borrador en curso, persistidos como JSON.
abstract interface class TemplateProfilesRepository {
  Map<String, TemplateProject> getProfiles();
  Future<void> saveProfiles(Map<String, TemplateProject> profiles);
  TemplateProject? getDraft();
  Future<void> saveDraft(TemplateProject project);
}

class TemplateProfilesRepositoryImpl(final SharedPreferences _prefs) implements TemplateProfilesRepository {
  static const _profilesKey = 'epub_templater_profiles';
  static const _draftKey = 'epub_templater_draft';

  @override
  Map<String, TemplateProject> getProfiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final MapEntry(:key, :value) in decoded.entries) key: TemplateProject.fromJson(value as Map<String, dynamic>)};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveProfiles(Map<String, TemplateProject> profiles) => _prefs.setString(_profilesKey, jsonEncode(profiles));

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
