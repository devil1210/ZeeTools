import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const fontExtensions = ['ttf', 'otf'];

const fontMediaTypes = {'ttf': 'font/ttf', 'otf': 'font/otf'};

typedef FontFace = ({String path, String family, String style, int weight, bool italic, bool embeddable});

// Las colecciones (.ttc) no son válidas en EPUB y WOFF/WOFF2 van comprimidos:
// solo se admiten TrueType y OpenType sin envolver.
Future<List<FontFace>> scanSystemFonts() => Isolate.run(() {
  final faces = <FontFace>[];
  for (final dir in _fontDirectories()) {
    final directory = Directory(dir);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.ttf' && ext != '.otf') continue;
      final face = readFontFace(entity.path);
      if (face != null) faces.add(face);
    }
  }
  faces.sort((a, b) => a.family.toLowerCase().compareTo(b.family.toLowerCase()));
  return faces;
});

List<String> _fontDirectories() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
  if (Platform.isWindows) {
    return [
      p.join(env['WINDIR'] ?? r'C:\Windows', 'Fonts'),
      if (env['LOCALAPPDATA'] case final local?) p.join(local, 'Microsoft', 'Windows', 'Fonts'),
    ];
  }
  if (Platform.isMacOS) return ['/System/Library/Fonts', '/Library/Fonts', p.join(home, 'Library', 'Fonts')];
  return ['/usr/share/fonts', '/usr/local/share/fonts', p.join(home, '.local', 'share', 'fonts'), p.join(home, '.fonts')];
}

// Lee solo el directorio de tablas y las tablas name y OS/2.
FontFace? readFontFace(String path) {
  RandomAccessFile? file;
  try {
    file = File(path).openSync();
    final header = ByteData.sublistView(file.readSync(12));
    final numTables = header.getUint16(4);
    final records = ByteData.sublistView(file.readSync(numTables * 16));
    final tables = <String, (int, int)>{};
    for (var i = 0; i < numTables; i++) {
      final tag = String.fromCharCodes(records.buffer.asUint8List(records.offsetInBytes + i * 16, 4));
      tables[tag] = (records.getUint32(i * 16 + 8), records.getUint32(i * 16 + 12));
    }
    ByteData? table(String tag) {
      final entry = tables[tag];
      if (entry == null) return null;
      file!.setPositionSync(entry.$1);
      return ByteData.sublistView(file.readSync(entry.$2));
    }

    final names = _parseNames(table('name'));
    final family = names[16] ?? names[1];
    if (family == null || family.isEmpty) return null;
    final os2 = table('OS/2');
    final weight = os2 != null && os2.lengthInBytes >= 6 ? os2.getUint16(4) : 400;
    final fsType = os2 != null && os2.lengthInBytes >= 10 ? os2.getUint16(8) : 0;
    final fsSelection = os2 != null && os2.lengthInBytes >= 64 ? os2.getUint16(62) : 0;
    return (
      path: path,
      family: family,
      style: names[17] ?? names[2] ?? 'Regular',
      weight: weight == 0 ? 400 : weight,
      italic: fsSelection & 0x1 != 0,
      // Bit 1 sin los de permisos superiores: licencia de incrustación restringida.
      embeddable: fsType & 0xF != 0x2,
    );
  } catch (_) {
    return null;
  } finally {
    file?.closeSync();
  }
}

// Prioriza los nombres de Windows en inglés (UTF-16BE) sobre los de Mac (Mac Roman).
Map<int, String> _parseNames(ByteData? data) {
  final names = <int, String>{};
  if (data == null || data.lengthInBytes < 6) return names;
  final count = data.getUint16(2);
  final stringOffset = data.getUint16(4);
  final priority = <int, int>{};
  for (var i = 0; i < count; i++) {
    final base = 6 + i * 12;
    if (base + 12 > data.lengthInBytes) break;
    final platform = data.getUint16(base);
    final encoding = data.getUint16(base + 2);
    final language = data.getUint16(base + 4);
    final nameId = data.getUint16(base + 6);
    final length = data.getUint16(base + 8);
    final offset = stringOffset + data.getUint16(base + 10);
    if (![1, 2, 16, 17].contains(nameId) || offset + length > data.lengthInBytes) continue;

    final int rank;
    final String value;
    if (platform == 3 && (encoding == 1 || encoding == 10)) {
      rank = language == 0x0409 ? 3 : 2;
      value = String.fromCharCodes([for (var j = 0; j + 1 < length; j += 2) data.getUint16(offset + j)]);
    } else if (platform == 1 && encoding == 0) {
      rank = 1;
      value = String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes + offset, length));
    } else {
      continue;
    }
    if (rank > (priority[nameId] ?? 0)) {
      priority[nameId] = rank;
      names[nameId] = value.trim();
    }
  }
  return names;
}
