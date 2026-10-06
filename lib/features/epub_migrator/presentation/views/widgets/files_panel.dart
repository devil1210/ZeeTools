import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/epub/utils/epub_file_kind.dart';
import '/common/theme/app_dimensions.dart';
import '/common/widgets/file_kind_icon.dart';
import '../../../domain/migration_project.dart';
import '../../cubit/epub_migrator_cubit.dart';
import 'file_preview.dart';

// Archivos del EPUB original por carpeta; los documentos muestran en qué se convierten.
class FilesPanel extends StatelessWidget {
  const FilesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    final archive = cubit.archive;
    final docs = context.select((EpubMigratorCubit c) => c.state.project?.docs ?? const <MigrationDoc>[]);
    final issues = context.select((EpubMigratorCubit c) => c.state.issues);
    if (archive == null) return const SizedBox.shrink();
    final byFolder = <String, List<String>>{};
    for (final path in archive.files.keys.toList()..sort()) {
      byFolder.putIfAbsent(p.posix.dirname(path), () => []).add(path);
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppPadding.small),
      children: [
        for (final MapEntry(key: folder, value: paths) in byFolder.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppPadding.medium + AppPadding.small, AppPadding.medium, AppPadding.medium, AppPadding.small),
            child: Text(folder == '.' ? 'Raíz' : folder, style: theme.textTheme.labelLarge),
          ),
          for (final path in paths)
            Builder(
              builder: (context) {
                final doc = docs.where((d) => d.path == path).firstOrNull;
                final level = issues.where((i) => i.path == path && i.level != MigrationIssueLevel.info).map((i) => i.level).fold<MigrationIssueLevel?>(null, (a, b) => a == MigrationIssueLevel.error ? a : b);
                final mediaType = archive.byPath(path)?.mediaType ?? '';
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: mediaType.startsWith('image/') ? const Icon(Icons.image_outlined, size: 20) : FileKindIcon(kind: EpubFileKind.fromMediaType(mediaType.isEmpty ? 'application/octet-stream' : mediaType)),
                  title: Text(p.posix.basename(path), overflow: TextOverflow.ellipsis),
                  subtitle: doc == null ? null : Text(doc.continuation ? '↳ se une a ${doc.fileName}.xhtml' : '→ ${doc.fileName}.xhtml', overflow: TextOverflow.ellipsis),
                  trailing: level == null ? null : Icon(level == MigrationIssueLevel.error ? Icons.error_outline : Icons.warning_amber_rounded, size: 18, color: level == MigrationIssueLevel.error ? theme.colorScheme.error : theme.colorScheme.tertiary),
                  onTap: () => showFilePreview(context, archive, path),
                );
              },
            ),
        ],
      ],
    );
  }
}
