import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '/common/utils/either.dart';
import '../../image_optimizer/domain/optimization_outcome.dart';
import '../domain/embedded_font.dart';
import '../domain/template_project.dart';
import 'epub_template_builder.dart';
import 'system_fonts.dart';

const _assetDir = 'assets/epub_templater';

// [warnings]: recursos que no se pudieron incluir.
typedef GeneratedEpub = ({Uint8List bytes, List<String> warnings});

abstract interface class EpubTemplaterRepository {
  // [optimized]: resultado del optimizador que sustituye a cada imagen de origen.
  Future<Either<String, GeneratedEpub>> generate(TemplateProject project, {Map<String, OptimizedOutcome> optimized = const {}});
  Future<List<FontFace>> systemFonts();
}

class EpubTemplaterRepositoryImpl implements EpubTemplaterRepository {
  Future<List<FontFace>>? _systemFonts;

  @override
  Future<List<FontFace>> systemFonts() => _systemFonts ??= scanSystemFonts();

  @override
  Future<Either<String, GeneratedEpub>> generate(TemplateProject project, {Map<String, OptimizedOutcome> optimized = const {}}) async {
    try {
      final warnings = <String>[];
      final images = <String, Uint8List>{};
      final sources = {
        for (final s in project.sections) ...[...s.images, if (s.headingImage.isNotEmpty) s.headingImage],
      };
      for (final source in sources) {
        final file = File(optimized[source]?.resultPath ?? source);
        if (await file.exists()) {
          images[source] = await file.readAsBytes();
        } else {
          warnings.add('No se encontró la imagen ${p.basename(source)}.');
        }
      }

      final fonts = <ResolvedFont>[];
      for (final font in project.fonts) {
        final faces = await _facesFor(font);
        if (faces.isEmpty) warnings.add('No se encontró la fuente «${font.family}».');
        if (faces.any((f) => !f.embeddable)) warnings.add('La licencia de «${font.family}» no permite incrustarla.');
        fonts.add((
          font: font,
          files: [for (final f in faces) (path: f.path, bytes: await File(f.path).readAsBytes(), weight: f.weight, italic: f.italic)],
        ));
      }

      final entries = EpubTemplateBuilder(
        project: project,
        styleCss: await rootBundle.loadString('$_assetDir/style.css'),
        navCss: await rootBundle.loadString('$_assetDir/nav-style.css'),
        images: images,
        extensionOverrides: {for (final MapEntry(:key, :value) in optimized.entries) key: value.format.extension},
        zeepubsLogo: (await rootBundle.load('$_assetDir/$zeepubsLogoName')).buffer.asUint8List(),
        fonts: fonts,
      ).build();

      // El mimetype debe ser la primera entrada y sin comprimir.
      final archive = Archive();
      for (final e in entries) {
        archive.addFile(e.path == 'mimetype' ? ArchiveFile.noCompress(e.path, e.bytes.length, e.bytes) : ArchiveFile(e.path, e.bytes.length, e.bytes));
      }
      return Either.right((bytes: ZipEncoder().encodeBytes(archive), warnings: warnings));
    } catch (e) {
      return Either.left(e.toString());
    }
  }

  // Sin archivos elegidos se toman del sistema la redonda, negrita y sus
  // cursivas, o el peso más cercano a cada una si la familia no las tiene.
  Future<List<FontFace>> _facesFor(EmbeddedFont font) async {
    if (font.files.isNotEmpty) {
      return [
        for (final path in font.files)
          if (File(path).existsSync()) readFontFace(path) ?? (path: path, family: font.family, style: 'Regular', weight: 400, italic: false, embeddable: true),
      ];
    }
    final family = (await systemFonts()).where((f) => f.family.toLowerCase() == font.family.trim().toLowerCase()).toList();
    final chosen = <String, FontFace>{};
    for (final italic in [false, true]) {
      final candidates = family.where((f) => f.italic == italic).toList();
      for (final target in [400, 700]) {
        if (candidates.isEmpty) continue;
        final best = candidates.reduce((a, b) => (a.weight - target).abs() <= (b.weight - target).abs() ? a : b);
        chosen[best.path] = best;
      }
    }
    return chosen.values.toList();
  }
}
