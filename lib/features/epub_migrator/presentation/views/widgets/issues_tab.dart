import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '../../../domain/migration_project.dart';
import '../../cubit/epub_migrator_cubit.dart';
import 'file_preview.dart';

const _groups = {
  MigrationIssueLevel.error: 'Errores: impiden guardar',
  MigrationIssueLevel.warning: 'Advertencias',
  MigrationIssueLevel.info: 'Notas',
};

class IssuesTab extends StatelessWidget {
  const IssuesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final issues = context.select((EpubMigratorCubit c) => c.state.issues);
    final written = context.select((EpubMigratorCubit c) => c.state.written);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        if (issues.every((i) => i.level == MigrationIssueLevel.info)) const ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Nada pendiente: el libro se puede guardar.')),
        for (final MapEntry(key: level, value: title) in _groups.entries)
          if (issues.where((i) => i.level == level).toList() case final group when group.isNotEmpty) _Group(title: '$title (${group.length})', issues: group),
        if (written case final changes? when changes.isNotEmpty) _Group(title: 'Corregido al guardar (${changes.length})', issues: changes),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.issues});

  final String title;
  final List<MigrationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archive = context.read<EpubMigratorCubit>().archive;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppPadding.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.small, AppPadding.large, AppPadding.small),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            for (final issue in issues)
              ListTile(
                dense: true,
                leading: switch (issue.level) {
                  MigrationIssueLevel.error => Icon(Icons.error_outline, color: theme.colorScheme.error),
                  MigrationIssueLevel.warning => Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary),
                  MigrationIssueLevel.info => Icon(Icons.info_outline, color: theme.colorScheme.outline),
                },
                title: Text(issue.message),
                subtitle: issue.path == null ? null : Text(p.posix.basename(issue.path!)),
                onTap: issue.path == null || archive == null || !archive.files.containsKey(issue.path) ? null : () => showFilePreview(context, archive, issue.path!),
              ),
          ],
        ),
      ),
    );
  }
}
