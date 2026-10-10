import 'package:flutter/material.dart';

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String icon;
  final bool isEnabled;
  final String directoryPath;
  final String? entryPoint;
  final Map<String, dynamic> extra;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    this.icon = 'extension',
    this.isEnabled = true,
    required this.directoryPath,
    this.entryPoint,
    this.extra = const {},
  });

  factory PluginManifest.fromJson(
    Map<String, dynamic> json,
    String directoryPath, {
    bool isEnabled = true,
  }) {
    return PluginManifest(
      id: json['id'] as String? ?? 'plugin_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Complemento sin nombre',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Desconocido',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'extension',
      isEnabled: isEnabled,
      directoryPath: directoryPath,
      entryPoint: json['entry_point'] as String?,
      extra: json,
    );
  }

  PluginManifest copyWith({
    bool? isEnabled,
  }) {
    return PluginManifest(
      id: id,
      name: name,
      version: version,
      author: author,
      description: description,
      icon: icon,
      isEnabled: isEnabled ?? this.isEnabled,
      directoryPath: directoryPath,
      entryPoint: entryPoint,
      extra: extra,
    );
  }

  IconData get iconData {
    return switch (icon.toLowerCase().trim()) {
      'auto_stories' => Icons.auto_stories_rounded,
      'menu_book' => Icons.menu_book_rounded,
      'book' => Icons.book_rounded,
      'library_books' => Icons.library_books_rounded,
      'translate' => Icons.translate_rounded,
      'find_replace' => Icons.find_replace_rounded,
      'palette' => Icons.palette_rounded,
      'image' => Icons.image_rounded,
      'tag' => Icons.tag_rounded,
      'terminal' => Icons.terminal_rounded,
      'code' => Icons.code_rounded,
      'cloud_download' => Icons.cloud_download_rounded,
      'cloud_upload' => Icons.cloud_upload_rounded,
      'send' => Icons.send_rounded,
      'settings' => Icons.settings_rounded,
      'build' => Icons.build_rounded,
      _ => Icons.extension_rounded,
    };
  }
}
