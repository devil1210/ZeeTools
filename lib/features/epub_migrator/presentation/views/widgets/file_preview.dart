import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '/common/theme/app_dimensions.dart';
import '../../../data/epub_archive.dart';
import '../../../data/xhtml_utils.dart';

final _imageFile = RegExp(r'\.(jpe?g|png|gif|webp|bmp)$', caseSensitive: false);
final _textFile = RegExp(r'\.(x?html?|css|opf|ncx|xml|txt|svg|js)$', caseSensitive: false);

Future<void> showFilePreview(BuildContext context, EpubArchive archive, String path) => showDialog<void>(
  context: context,
  builder: (_) => _FilePreviewDialog(archive: archive, path: path),
);

class _FilePreviewDialog extends StatelessWidget {
  const _FilePreviewDialog({required this.archive, required this.path});

  final EpubArchive archive;
  final String path;

  @override
  Widget build(BuildContext context) {
    final bytes = archive.files[path];
    final size = MediaQuery.sizeOf(context);
    final isDocument = RegExp(r'\.x?html?$', caseSensitive: false).hasMatch(path);
    final Widget content;
    if (bytes == null) {
      content = const Center(child: Text('El archivo no está en el EPUB.'));
    } else if (_imageFile.hasMatch(path)) {
      content = InteractiveViewer(child: Center(child: Image.memory(bytes)));
    } else if (_textFile.hasMatch(path)) {
      final source = SingleChildScrollView(
        padding: const EdgeInsets.all(AppPadding.large),
        child: SelectableText(utf8.decode(bytes, allowMalformed: true), style: const TextStyle(fontFamily: 'Consolas', fontSize: 13)),
      );
      content = !isDocument
          ? source
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(tabs: [Tab(text: 'Texto'), Tab(text: 'Código')]),
                  Expanded(child: TabBarView(children: [_Reading(archive: archive, path: path), source])),
                ],
              ),
            );
    } else {
      content = Center(child: Text('${(bytes.length / 1024).toStringAsFixed(1)} KB sin vista previa.'));
    }
    return Dialog(
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium, AppPadding.small, 0),
              child: Row(
                children: [
                  Expanded(child: SelectableText(path, style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// El documento como se leería: encabezados, párrafos e imágenes en orden.
class _Reading extends StatelessWidget {
  const _Reading({required this.archive, required this.path});

  final EpubArchive archive;
  final String path;

  @override
  Widget build(BuildContext context) {
    final XmlDocument doc;
    try {
      doc = parseXhtml(archive.text(path));
    } on XmlException catch (e) {
      return Center(child: Text('No es XML bien formado: ${e.message}'));
    }
    final body = bodyOf(doc);
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    for (final e in body?.descendants.whereType<XmlElement>() ?? const <XmlElement>[]) {
      final name = localName(e);
      final classes = classesOf(e);
      final hidden = classes.any({'hidden', 'oculto'}.contains);
      if (isHeading(e)) {
        final label = headingLabel(e);
        blocks.add(
          Text(
            [label.isEmpty ? '(sin texto)' : label, if ((e.getAttribute('title') ?? '').isNotEmpty) '[índice: ${e.getAttribute('title')}]', if (hidden) '(oculto)', if (classes.contains('sigil_not_in_toc')) '(fuera del índice)'].join(' '),
            style: theme.textTheme.titleMedium?.copyWith(color: hidden ? theme.colorScheme.outline : null),
          ),
        );
      } else if (name == 'p' && !e.ancestors.whereType<XmlElement>().any(isHeading)) {
        blocks.add(Text(textOf(e)));
      } else if (name == 'img') {
        final bytes = archive.files[resolvePath(path, e.getAttribute('src') ?? '')];
        blocks.add(
          bytes == null
              ? Text('[imagen no encontrada: ${e.getAttribute('src')}]', style: TextStyle(color: theme.colorScheme.error))
              : Align(alignment: Alignment.centerLeft, child: Image.memory(bytes, height: 240)),
        );
      }
    }
    if (blocks.isEmpty) return const Center(child: Text('Sin texto ni imágenes.'));
    return ListView.separated(
      padding: const EdgeInsets.all(AppPadding.large),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.medium),
      itemBuilder: (_, i) => blocks[i],
    );
  }
}
