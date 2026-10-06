import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

typedef ManifestItem = ({String id, String path, String mediaType, String properties});

// Contenido de un EPUB en memoria: archivos, OPF, manifiesto y orden de lectura.
class EpubArchive {
  EpubArchive._(this.files, this.opfPath, this.opf, this.manifest, this.spine);

  factory EpubArchive.decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, Uint8List>{
      for (final f in archive.files)
        if (f.isFile) f.name: f.content,
    };
    final container = files['META-INF/container.xml'];
    if (container == null) throw const FormatException('falta META-INF/container.xml');
    final opfPath = XmlDocument.parse(utf8.decode(container)).findAllElements('rootfile').first.getAttribute('full-path') ?? '';
    final opfBytes = files[opfPath];
    if (opfBytes == null) throw FormatException('falta el OPF $opfPath');
    final opf = XmlDocument.parse(utf8.decode(opfBytes, allowMalformed: true));
    final manifest = [
      for (final item in opf.descendants.whereType<XmlElement>().where((e) => e.name.local == 'item')) (id: item.getAttribute('id') ?? '', path: resolvePath(opfPath, item.getAttribute('href') ?? ''), mediaType: item.getAttribute('media-type') ?? '', properties: item.getAttribute('properties') ?? ''),
    ];
    final spine = [
      for (final ref in opf.descendants.whereType<XmlElement>().where((e) => e.name.local == 'itemref')) (idref: ref.getAttribute('idref') ?? '', linear: ref.getAttribute('linear') != 'no'),
    ];
    return EpubArchive._(files, opfPath, opf, manifest, spine);
  }

  final Map<String, Uint8List> files;
  final String opfPath;
  final XmlDocument opf;
  final List<ManifestItem> manifest;
  final List<({String idref, bool linear})> spine;

  String text(String path) => utf8.decode(files[path] ?? Uint8List(0), allowMalformed: true);

  ManifestItem? byPath(String path) => manifest.where((i) => i.path == path).firstOrNull;

  ManifestItem? get nav => manifest.where((i) => i.properties.split(' ').contains('nav')).firstOrNull;

  ManifestItem? get ncx => manifest.where((i) => i.mediaType == 'application/x-dtbncx+xml').firstOrNull;

  List<ManifestItem> get spineItems => [
    for (final ref in spine) ?manifest.where((i) => i.id == ref.idref).firstOrNull,
  ];
}

// Ruta dentro del EPUB de [href] escrito en el archivo [from], sin fragmento.
String resolvePath(String from, String href) {
  final raw = href.split('#').first.trim().replaceAll('&amp;', '&');
  final String clean;
  try {
    clean = Uri.decodeFull(raw);
  } on ArgumentError {
    // Un «%» que no es un escape válido: la ruta se toma tal cual.
    return _join(from, raw);
  }
  return _join(from, clean);
}

String _join(String from, String path) => path.isEmpty ? from : p.posix.normalize(p.posix.join(p.posix.dirname(from), path)).replaceFirst(RegExp(r'^\./'), '');

String relativePath(String from, String to) => p.posix.relative(to, from: p.posix.dirname(from));

bool isExternal(String href) => RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(href.trim());

// Tipo de imagen según su contenido; null si no es una imagen legible.
String? imageTypeOf(Uint8List bytes) => switch (img.findFormatForData(bytes)) {
  img.ImageFormat.jpg => 'image/jpeg',
  img.ImageFormat.png => 'image/png',
  img.ImageFormat.gif => 'image/gif',
  img.ImageFormat.webp => 'image/webp',
  img.ImageFormat.invalid => null,
  final other => 'image/${other.name}',
};
