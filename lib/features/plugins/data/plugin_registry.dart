import '../domain/plugin_extension.dart';

class PluginRegistry {
  final Map<String, ZeeToolsPluginExtension> _extensions = {};

  void register(ZeeToolsPluginExtension extension) {
    _extensions[extension.id] = extension;
  }

  void unregister(String id) {
    _extensions.remove(id);
  }

  ZeeToolsPluginExtension? get(String id) => _extensions[id];

  bool has(String id) => _extensions.containsKey(id);
}
