import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/inject_dependencies.dart';
import '/common/widgets/confirm_dialog.dart';
import '/common/widgets/empty_state_pane.dart';
import '/common/widgets/file_drop_area.dart';
import '/common/widgets/resizable_split_panel.dart';
import '/common/widgets/speed_dial.dart';
import '/features/epub_templater/domain/book_metadata.dart';
import '/features/epub_templater/presentation/views/widgets/metadata_form.dart';
import '../cubit/metadata_editor_cubit.dart';

class MetadataEditorView extends StatelessWidget {
  const MetadataEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<MetadataEditorCubit>(),
      child: const _MetadataEditorContent(),
    );
  }
}

class _MetadataEditorContent extends StatefulWidget {
  const _MetadataEditorContent();

  @override
  State<_MetadataEditorContent> createState() => _MetadataEditorContentState();
}

class _MetadataEditorContentState extends State<_MetadataEditorContent> {
  final _fabNotifier = getIt<ValueNotifier<List<SpeedDialAction>>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFab(hasEpubs: false));
  }

  @override
  void dispose() {
    // Diferir la limpieza al siguiente frame — el árbol está bloqueado durante dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fabNotifier.value = []);
    super.dispose();
  }

  void _updateFab({required bool hasEpubs}) {
    _fabNotifier.value = hasEpubs
        ? [
            SpeedDialAction(icon: Icons.file_open_outlined, label: 'Añadir EPUBs…', onPressed: _pickFiles),
            SpeedDialAction(icon: Icons.folder_outlined, label: 'Añadir de una carpeta…', onPressed: _pickDirectory),
          ]
        : [];
  }

  Future<void> _pickFiles() async {
    final paths = (await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      dialogTitle: 'Seleccionar EPUBs',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    )).map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty && mounted) await context.read<MetadataEditorCubit>().open(paths);
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Seleccionar carpeta con EPUBs',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    if (path != null && mounted) await context.read<MetadataEditorCubit>().open([path]);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MetadataEditorCubit>();
    return MultiBlocListener(
      listeners: [
        BlocListener<MetadataEditorCubit, MetadataEditorState>(
          listenWhen: (a, b) => a.epubs.isEmpty != b.epubs.isEmpty,
          listener: (context, state) => _updateFab(hasEpubs: state.epubs.isNotEmpty),
        ),
        BlocListener<MetadataEditorCubit, MetadataEditorState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: state.message!.isError ? Theme.of(context).colorScheme.error : null,
              content: Text(state.message!.text),
            ),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editor de metadatos'),
          actions: const [_AppBarActions()],
        ),
        body: FileDropArea(
          label: 'Suelta aquí EPUBs o carpetas',
          onDrop: cubit.open,
          child: BlocBuilder<MetadataEditorCubit, MetadataEditorState>(
            buildWhen: (a, b) => a.epubs.length != b.epubs.length || a.busy != b.busy || a.recursive != b.recursive,
            builder: (context, state) {
              if (state.epubs.isEmpty) {
                if (state.busy) return const Center(child: CircularProgressIndicator());
                return EmptyStatePane(
                  icon: Icons.edit_note_outlined,
                  title: 'Arrastra aquí uno o varios EPUBs, o carpetas',
                  subtitle: 'Con varios, los campos que difieren se muestran vacíos y solo cambian en todos si les das un valor.',
                  primary: (icon: Icons.file_open_outlined, label: 'Abrir EPUBs…', onPressed: _pickFiles),
                  secondary: (icon: Icons.folder_open_outlined, label: 'Abrir carpeta…', onPressed: _pickDirectory),
                  recursive: state.recursive,
                  recursiveLabel: 'Incluir subcarpetas',
                  onRecursiveChanged: cubit.setRecursive,
                );
              }
              if (state.epubs.length == 1) return const _Form();
              return const ResizableSplitPanel(
                initialWidth: 300,
                maxWidth: 480,
                panel: _EpubList(),
                body: _Form(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppBarActions extends StatelessWidget {
  const _AppBarActions();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MetadataEditorCubit>();
    final (:count, :dirty, :busy) = context.select((MetadataEditorCubit c) => (count: c.state.epubs.length, dirty: c.state.epubs.where(c.state.isDirty).length, busy: c.state.busy));
    if (count == 0) return const SizedBox.shrink();
    return Row(
      children: [
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Descartar cambios',
          onPressed: busy || dirty == 0 ? null : cubit.discardChanges,
        ),
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: count == 1 ? 'Guardar' : 'Guardar $dirty EPUB${dirty == 1 ? '' : 's'}',
          onPressed: busy || dirty == 0 ? null : cubit.save,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: count == 1 ? 'Cerrar' : 'Cerrar todos',
          onPressed: busy
              ? null
              : () async {
                  final confirmed =
                      dirty == 0 ||
                      await confirmAction(
                        context,
                        title: 'Cerrar sin guardar',
                        message: 'Se perderán los cambios de $dirty EPUB${dirty == 1 ? '' : 's'}.',
                        confirmLabel: 'Cerrar',
                      );
                  if (confirmed) cubit.closeAll();
                },
        ),
      ],
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MetadataEditorCubit>();
    final state = context.watch<MetadataEditorCubit>().state;
    return MetadataForm(
      key: ValueKey(state.revision),
      metadata: state.form,
      mixed: state.mixed,
      multiple: state.epubs.length > 1,
      showLinks: false,
      onChanged: cubit.updateForm,
      onRegenerateIdentifier: state.epubs.length == 1 ? cubit.regenerateIdentifier : null,
    );
  }
}

// Cada libro con el título y el volumen que tendrá al guardar, para revisar una serie de un vistazo.
class _EpubList extends StatelessWidget {
  const _EpubList();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MetadataEditorCubit>();
    final state = context.watch<MetadataEditorCubit>().state;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          color: cs.surfaceContainerHighest,
          child: Text('EPUBs (${state.epubs.length})', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.epubs.length,
            itemBuilder: (context, i) {
              final epub = state.epubs[i];
              final m = state.edited(epub);
              final dirty = m != epub.metadata;
              return ListTile(
                dense: true,
                leading: Icon(dirty ? Icons.edit : Icons.menu_book_outlined, size: 20, color: dirty ? cs.primary : cs.outline),
                title: Text(m.title.isEmpty ? p.basenameWithoutExtension(epub.path) : m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [if (m.hasSeries) '${m.series} · vol. ${m.seriesIndex}', p.basename(epub.path)].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Quitar de la lista',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: state.busy ? null : () => cubit.remove(epub.path),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
