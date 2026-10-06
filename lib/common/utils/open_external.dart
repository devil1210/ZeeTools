import 'dart:io';

// Abre una carpeta o una URL con el programa del sistema (explorador de archivos o navegador).
Future<void> openExternal(String target) async {
  if (Platform.isWindows) {
    await Process.run('explorer', [target]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [target]);
  } else {
    await Process.run('xdg-open', [target]);
  }
}
