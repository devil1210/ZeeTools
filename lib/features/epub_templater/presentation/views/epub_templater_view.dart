import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/confirm_dialog.dart';
import '/common/widgets/resizable_split_panel.dart';
import '/common/widgets/speed_dial.dart';
import '/inject_dependencies.dart';
import '../../data/epub_template_builder.dart';
import '../../domain/book_metadata.dart';
import '../cubit/epub_templater_cubit.dart';
import 'widgets/fonts_form.dart';
import 'widgets/images_form.dart';
import 'widgets/metadata_form.dart';
import 'widgets/profile_bar.dart';
import 'widgets/section_editor.dart';
import 'widgets/sections_panel.dart';

class EpubTemplaterView extends StatelessWidget {
  const EpubTemplaterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EpubTemplaterCubit>(),
      child: const _EpubTemplaterContent(),
    );
  }
}

class _EpubTemplaterContent extends StatefulWidget {
  const _EpubTemplaterContent();

  @override
  State<_EpubTemplaterContent> createState() => _EpubTemplaterContentState();
}

class _EpubTemplaterContentState extends State<_EpubTemplaterContent> {
  final _fabNotifier = getIt<ValueNotifier<List<SpeedDialAction>>>();

  @override
  void initState() {
    super.initState();
    // El shell construye el FAB a partir del notificador; se publica tras el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fabNotifier.value = [
        SpeedDialAction(icon: Icons.note_add_outlined, label: 'Nueva plantilla', onPressed: _confirmReset),
        SpeedDialAction(icon: Icons.save_alt, label: 'Generar EPUB…', onPressed: _generate),
      ];
    });
  }

  @override
  void dispose() {
    // Diferir la limpieza al siguiente frame — el árbol está bloqueado durante dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fabNotifier.value = [];
    });
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final confirmed = await confirmAction(
      context,
      title: 'Nueva plantilla',
      message: 'Se descartarán las secciones, los metadatos y las fuentes actuales que no estén guardados en un perfil.',
      confirmLabel: 'Empezar de nuevo',
    );
    if (confirmed && mounted) context.read<EpubTemplaterCubit>().resetProject();
  }

  Future<void> _generate() async {
    final cubit = context.read<EpubTemplaterCubit>();
    final errors = templateIssues(cubit.state.project).where((i) => i.level == IssueLevel.error).toList();
    if (errors.isNotEmpty) {
      cubit.notify(errors.first.message, isError: true);
      return;
    }
    final epub = await cubit.generate();
    if (epub == null || !mounted) return;
    final saved = await FilePicker.saveFile(
      fileName: _suggestedFileName(cubit.state.project.metadata),
      bytes: epub.bytes,
      mimeType: 'application/epub+zip',
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      dialogTitle: 'Guardar EPUB',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    if (saved == null) return;
    cubit.notify(epub.warnings.isEmpty ? 'EPUB guardado.' : 'EPUB guardado. ${epub.warnings.join(' ')}', isError: epub.warnings.isNotEmpty);
  }

  // Título en el idioma del libro, volumen y grupo: «Título - V03 [Grupo].epub».
  static String _suggestedFileName(BookMetadata m) {
    final base = m.language.split('-').first.toLowerCase();
    final local = m.altTitles.where((t) => t.lang.split('-').first.toLowerCase() == base && t.text.trim().isNotEmpty).firstOrNull?.text.trim() ?? m.title.trim();
    final volume = m.hasSeries ? ' - V${m.seriesIndex.trim().padLeft(2, '0')}' : '';
    final publisher = m.publishers.where((x) => x.trim().isNotEmpty).firstOrNull;
    final name = '$local$volume${publisher == null ? '' : ' [${publisher.trim()}]'}'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    return '${name.isEmpty ? 'plantilla' : name}.epub';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EpubTemplaterCubit, EpubTemplaterState>(
      listenWhen: (p, c) => c.message != null && p.message != c.message,
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
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Plantillas EPUB'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.list_alt), text: 'Secciones'),
                Tab(icon: Icon(Icons.badge_outlined), text: 'Metadatos'),
                Tab(icon: Icon(Icons.photo_library_outlined), text: 'Imágenes'),
                Tab(icon: Icon(Icons.font_download_outlined), text: 'Fuentes'),
              ],
            ),
          ),
          body: Column(
            children: [
              const ProfileBar(),
              const _IssuesBanner(),
              if (context.select((EpubTemplaterCubit c) => c.state.generating)) const LinearProgressIndicator(),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    const ResizableSplitPanel(initialWidth: 300, maxWidth: 520, panel: SectionsPanel(), body: SectionEditor()),
                    MetadataForm(
                      key: ValueKey(context.select((EpubTemplaterCubit c) => c.state.revision)),
                      metadata: context.select((EpubTemplaterCubit c) => c.state.project.metadata),
                      onChanged: context.read<EpubTemplaterCubit>().updateMetadata,
                      onRegenerateIdentifier: context.read<EpubTemplaterCubit>().regenerateIdentifier,
                    ),
                    const ImagesForm(),
                    const FontsForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Los problemas de metadatos ya se señalan en su campo; aquí solo los de secciones y fuentes.
class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner();

  @override
  Widget build(BuildContext context) {
    final issues = templateIssues(context.select((EpubTemplaterCubit c) => c.state.project)).where((i) => i.scope != IssueScope.metadata).toList();
    if (issues.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Widget icon(TemplateIssue issue, double size) => issue.level == IssueLevel.error ? Icon(Icons.error_outline, size: size, color: scheme.error) : Icon(Icons.warning_amber_rounded, size: size, color: scheme.tertiary);
    return Material(
      color: scheme.surfaceContainerHigh,
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppPadding.large),
        leading: icon(issues.first, 20),
        title: Text(issues.first.message),
        subtitle: issues.length > 1 ? Text('y ${issues.length - 1} aviso${issues.length == 2 ? '' : 's'} más') : null,
        childrenPadding: const EdgeInsets.fromLTRB(AppPadding.large, 0, AppPadding.large, AppPadding.medium),
        expandedAlignment: Alignment.centerLeft,
        children: [
          for (final issue in issues.skip(1))
            Row(
              spacing: AppSpacing.medium,
              children: [
                icon(issue, 16),
                Expanded(child: Text(issue.message)),
              ],
            ),
        ],
      ),
    );
  }
}
