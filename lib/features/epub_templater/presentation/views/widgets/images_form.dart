import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/toggle_field.dart';
import '/common/widgets/file_drop_button.dart';
import '/common/widgets/form_section.dart';
import '../../../../image_optimizer/domain/image_format.dart';
import '../../../../image_optimizer/domain/optimization_options.dart';
import '../../../../image_optimizer/presentation/views/widgets/job_status.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

class ImagesForm extends StatelessWidget {
  const ImagesForm({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = context.select((EpubTemplaterCubit c) => c.state.project.sections);
    final withImages = sections.where((s) => s.kind.acceptsImages || (s.kind.layout == SectionLayout.text && s.headingStyle.usesImage)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
      children: [
        const _OptimizationOptions(),
        for (final s in withImages) _SectionImages(key: ValueKey(s.key), section: s),
      ],
    );
  }
}

class _OptimizationOptions extends StatelessWidget {
  const _OptimizationOptions();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final state = context.watch<EpubTemplaterCubit>().state;
    final pending = state.imagePaths.where((path) => state.imageJobs[path] == null).length;
    return FormSection(
      title: 'Optimización',
      children: [
        Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final format in ImageFormat.outputs)
              SelectionPill(
                selected: state.allowedFormats.contains(format),
                onTap: () => cubit.setAllowedFormats(
                  state.allowedFormats.contains(format) ? ([...state.allowedFormats]..remove(format)) : [...state.allowedFormats, format],
                ),
                child: Text(format.label),
              ),
          ],
        ),
        SegmentedButton<QualityMode>(
          showSelectedIcon: false,
          segments: [for (final mode in QualityMode.values) ButtonSegment(value: mode, label: Text(mode.label))],
          selected: {state.qualityMode},
          onSelectionChanged: (v) => cubit.setQualityMode(v.first),
        ),
        ToggleField(
          label: 'Permitir cambiar de formato',
          value: state.allowConversion,
          onChanged: cubit.setAllowConversion,
        ),
        FilledButton.icon(
          icon: state.optimizing ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high),
          label: Text(state.optimizeStatus ?? (pending == 0 ? 'Imágenes optimizadas' : 'Optimizar $pending imagen${pending == 1 ? '' : 'es'}')),
          onPressed: state.optimizing || pending == 0 ? null : cubit.optimizeImages,
        ),
      ],
    );
  }
}

class _SectionImages extends StatelessWidget {
  const _SectionImages({super.key, required this.section});

  final TemplateSection section;

  Future<List<String>> _pick({required bool multiple}) async {
    final paths = (await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageExtensions,
      dialogTitle: 'Seleccionar imágenes',
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    )).map((f) => f.path).whereType<String>().toList();
    return multiple ? paths : paths.take(1).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final s = section;
    void update(TemplateSection Function(TemplateSection s) f) => cubit.updateSection(s.key, f);

    if (s.kind.layout == SectionLayout.text) {
      return FormSection(
        title: '${s.effectiveTocLabel} · ${s.headingStyle.label}',
        children: [
          if (s.headingImage.isNotEmpty)
            _ImageRow(
              path: s.headingImage,
              onRemove: () => update((s) => s.copyWith(headingImage: '')),
            ),
          FileDropButton(
            icon: Icons.add_photo_alternate_outlined,
            label: s.headingImage.isEmpty ? 'Elegir imagen…' : 'Cambiar imagen…',
            dropLabel: 'Suelta aquí la imagen',
            extensions: imageExtensions,
            onPick: () async {
              final picked = await _pick(multiple: false);
              if (picked.isNotEmpty) update((s) => s.copyWith(headingImage: picked.first));
            },
            onFiles: (files) => update((s) => s.copyWith(headingImage: files.first)),
          ),
        ],
      );
    }

    return FormSection(
      title: s.effectiveTocLabel,
      children: [
        for (final (i, path) in s.images.indexed)
          _ImageRow(
            path: path,
            onUp: s.kind.singleImage || i == 0
                ? null
                : () => update(
                    (s) => s.copyWith(
                      images: [...s.images]
                        ..removeAt(i)
                        ..insert(i - 1, path),
                    ),
                  ),
            onDown: s.kind.singleImage || i == s.images.length - 1
                ? null
                : () => update(
                    (s) => s.copyWith(
                      images: [...s.images]
                        ..removeAt(i)
                        ..insert(i + 1, path),
                    ),
                  ),
            onRemove: () => update((s) => s.copyWith(images: [...s.images]..removeAt(i))),
          ),
        FileDropButton(
          icon: Icons.add_photo_alternate_outlined,
          label: s.kind.singleImage ? (s.images.isEmpty ? 'Elegir imagen…' : 'Cambiar imagen…') : 'Añadir imágenes…',
          dropLabel: s.kind.singleImage ? 'Suelta aquí la imagen' : 'Suelta aquí las imágenes',
          extensions: imageExtensions,
          onPick: () async {
            final picked = await _pick(multiple: !s.kind.singleImage);
            if (picked.isNotEmpty) update((s) => s.copyWith(images: s.kind.singleImage ? picked : [...s.images, ...picked]));
          },
          onFiles: (files) => update((s) => s.copyWith(images: s.kind.singleImage ? [files.first] : [...s.images, ...files])),
        ),
        if (s.kind.layout == SectionLayout.colophon)
          ToggleField(
            label: 'Incluir logo de ZeePubs',
            value: s.zeepubsLogo,
            onChanged: (v) => update((s) => s.copyWith(zeepubsLogo: v)),
          ),
      ],
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.path, required this.onRemove, this.onUp, this.onDown});

  final String path;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final job = context.select((EpubTemplaterCubit c) => c.state.imageJobs[path]);
    final exists = File(path).existsSync();
    return Row(
      spacing: AppSpacing.medium,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: SizedBox.square(
            dimension: AppSize.large,
            child: exists ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 96) : const Icon(Icons.broken_image_outlined),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (exists) JobStatus(job: job) else Text('No se encuentra el archivo', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        if (onUp != null || onDown != null) ...[
          IconButton(tooltip: 'Subir', icon: const Icon(Icons.arrow_upward, size: 18), onPressed: onUp),
          IconButton(tooltip: 'Bajar', icon: const Icon(Icons.arrow_downward, size: 18), onPressed: onDown),
        ],
        IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
      ],
    );
  }
}
