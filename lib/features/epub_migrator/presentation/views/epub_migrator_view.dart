import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/widgets/confirm_dialog.dart';
import '/common/widgets/file_drop_area.dart';
import '/common/widgets/resizable_split_panel.dart';
import '/common/widgets/speed_dial.dart';
import '/features/epub_templater/presentation/views/widgets/metadata_form.dart';
import '/inject_dependencies.dart';
import '../../domain/migration_project.dart';
import '../cubit/epub_migrator_cubit.dart';
import 'widgets/files_panel.dart';
import 'widgets/issues_tab.dart';
import 'widgets/sections_tab.dart';
import 'widgets/styles_tab.dart';

class EpubMigratorView extends StatelessWidget {
  const EpubMigratorView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EpubMigratorCubit>(),
      child: const _EpubMigratorContent(),
    );
  }
}

class _EpubMigratorContent extends StatefulWidget {
  const _EpubMigratorContent();

  @override
  State<_EpubMigratorContent> createState() => _EpubMigratorContentState();
}

class _EpubMigratorContentState extends State<_EpubMigratorContent> {
  final _fabNotifier = getIt<ValueNotifier<List<SpeedDialAction>>>();

  @override
  void dispose() {
    // Diferir la limpieza al siguiente frame — el árbol está bloqueado durante dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fabNotifier.value = []);
    super.dispose();
  }

  void _updateFab({required bool open}) {
    _fabNotifier.value = open
        ? [
            SpeedDialAction(icon: Icons.file_open_outlined, label: 'Abrir otro EPUB…', onPressed: _pick),
            SpeedDialAction(icon: Icons.save_alt, label: 'Guardar EPUB migrado…', onPressed: _save),
          ]
        : [];
  }

  Future<void> _pick() async {
    final path = (await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      dialogTitle: 'Abrir EPUB para migrar',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    )).map((f) => f.path).whereType<String>().firstOrNull;
    if (path != null && mounted) await _open([path]);
  }

  Future<void> _open(List<String> paths) async {
    final cubit = context.read<EpubMigratorCubit>();
    final epubs = paths.where((x) => p.extension(x).toLowerCase() == '.epub').toList();
    if (epubs.length != 1) {
      cubit.notify('Suelta un solo EPUB: cada libro se migra por separado.', isError: true);
      return;
    }
    await cubit.open(epubs.first);
  }

  Future<void> _save() async {
    final cubit = context.read<EpubMigratorCubit>();
    final source = cubit.state.project?.sourcePath;
    final bytes = await cubit.migrate();
    if (bytes == null || source == null || !mounted) return;
    final saved = await FilePicker.saveFile(
      fileName: p.basename(source),
      bytes: bytes,
      mimeType: 'application/epub+zip',
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      dialogTitle: 'Guardar EPUB migrado',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    if (saved != null) cubit.notify('EPUB migrado guardado.');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    return MultiBlocListener(
      listeners: [
        BlocListener<EpubMigratorCubit, EpubMigratorState>(
          listenWhen: (a, b) => (a.project == null) != (b.project == null),
          listener: (context, state) => _updateFab(open: state.project != null),
        ),
        BlocListener<EpubMigratorCubit, EpubMigratorState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, state) {
            final message = state.message!;
            final scheme = Theme.of(context).colorScheme;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(message.text, style: message.isError ? TextStyle(color: scheme.onErrorContainer) : null),
                  backgroundColor: message.isError ? scheme.errorContainer : null,
                ),
              );
          },
        ),
      ],
      child: BlocBuilder<EpubMigratorCubit, EpubMigratorState>(
        buildWhen: (a, b) => (a.project == null) != (b.project == null) || a.busy != b.busy || a.revision != b.revision,
        builder: (context, state) {
          final project = state.project;
          return Scaffold(
            appBar: AppBar(
              title: Text(project == null ? 'Migrar EPUB' : 'Migrar · ${p.basename(project.sourcePath)}'),
              actions: [
                if (state.busy)
                  const Padding(
                    padding: EdgeInsets.only(right: AppPadding.medium + AppPadding.small),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (project != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () async {
                      final confirmed = await confirmAction(context, title: 'Cerrar sin guardar', message: 'Se perderá lo revisado de este libro.', confirmLabel: 'Cerrar');
                      if (confirmed) cubit.closeBook();
                    },
                  ),
              ],
            ),
            body: FileDropArea(
              label: 'Suelta aquí un EPUB',
              onDrop: _open,
              child: project == null
                  ? _EmptyPane(busy: state.busy, onPick: _pick)
                  : ResizableSplitPanel(
                      key: ValueKey(state.revision),
                      initialWidth: 260,
                      maxWidth: 480,
                      panel: const FilesPanel(),
                      body: _Tabs(revision: state.revision),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.busy, required this.onPick});

  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Icon(Icons.auto_fix_high_outlined, size: 64, color: scheme.outline),
            const Text('Arrastra aquí un EPUB con el template anterior', textAlign: TextAlign.center),
            Text(
              'Se propone la estructura nueva: tipo y nombre de cada sección, metadatos, clases y CSS propio. Revisa lo pendiente y guarda el EPUB migrado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
            FilledButton.icon(icon: const Icon(Icons.file_open_outlined), label: const Text('Abrir EPUB…'), onPressed: onPick),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.revision});

  final int revision;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubMigratorCubit>();
    final issues = context.select((EpubMigratorCubit c) => c.state.issues);
    final errors = issues.where((i) => i.level == MigrationIssueLevel.error).length;
    final warnings = issues.where((i) => i.level == MigrationIssueLevel.warning).length;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.list_alt), text: 'Secciones'),
              const Tab(icon: Icon(Icons.badge_outlined), text: 'Metadatos'),
              const Tab(icon: Icon(Icons.style_outlined), text: 'Estilos'),
              Tab(
                icon: Badge(
                  isLabelVisible: errors + warnings > 0,
                  label: Text('${errors + warnings}'),
                  backgroundColor: errors > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                  child: const Icon(Icons.pending_actions_outlined),
                ),
                text: 'Pendientes',
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                const SectionsTab(),
                MetadataForm(
                  key: ValueKey(revision),
                  metadata: context.select((EpubMigratorCubit c) => c.state.project!.metadata),
                  onChanged: cubit.updateMetadata,
                  showLinks: false,
                ),
                StylesTab(key: ValueKey(revision)),
                const IssuesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
