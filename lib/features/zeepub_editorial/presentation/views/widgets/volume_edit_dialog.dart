import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/data/models/zeepub_workgroup.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_cubit.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_state.dart';

class VolumeEditDialog extends StatefulWidget {
  final ZeepubVolume volume;
  final List<ZeepubWorkgroup> workgroups;
  final String baseUrl;

  const VolumeEditDialog({
    super.key,
    required this.volume,
    required this.workgroups,
    required this.baseUrl,
  });

  @override
  State<VolumeEditDialog> createState() => _VolumeEditDialogState();
}

class _VolumeEditDialogState extends State<VolumeEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _spanishTitleController;
  late final TextEditingController _englishTitleController;
  late final TextEditingController _volumeController;
  late final TextEditingController _editionController;
  late final TextEditingController _authorController;
  late final TextEditingController _illustratorController;
  late final TextEditingController _translatorController;
  late final TextEditingController _layoutByController;
  late final TextEditingController _publisherController;
  late final TextEditingController _descriptionController;

  late String _colorMode;
  late bool _isUncensored;

  @override
  void initState() {
    super.initState();
    final v = widget.volume;
    _titleController = TextEditingController(text: v.title);
    _spanishTitleController = TextEditingController(text: v.spanishTitle);
    _englishTitleController = TextEditingController(text: v.englishTitle);
    _volumeController = TextEditingController(text: v.volume != null ? (v.volume! % 1 == 0 ? v.volume!.toInt().toString() : v.volume!.toString()) : '');
    _editionController = TextEditingController(text: v.edition ?? '');
    _authorController = TextEditingController(text: v.author ?? '');
    _illustratorController = TextEditingController(text: v.illustrator ?? '');
    _translatorController = TextEditingController(text: v.translator ?? '');
    _layoutByController = TextEditingController(text: v.layoutBy ?? '');
    _publisherController = TextEditingController(text: v.publisher ?? '');
    _descriptionController = TextEditingController(text: v.description ?? '');
    _colorMode = v.colorMode ?? ((v.filename ?? '').toLowerCase().contains('[color]') ? 'color' : 'bw');
    _isUncensored = v.isUncensored;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _spanishTitleController.dispose();
    _englishTitleController.dispose();
    _volumeController.dispose();
    _editionController.dispose();
    _authorController.dispose();
    _illustratorController.dispose();
    _translatorController.dispose();
    _layoutByController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _applyAiSuggestion(ZeepubEditorialState state) {
    final s = state.latestAiSuggestion;
    if (s == null) return;
    if (s.spanishTitle.isNotEmpty) _spanishTitleController.text = s.spanishTitle;
    if (s.englishTitle.isNotEmpty) _englishTitleController.text = s.englishTitle;
    if (s.author.isNotEmpty) _authorController.text = s.author;
    if (s.volume != null) {
      _volumeController.text = s.volume! % 1 == 0 ? s.volume!.toInt().toString() : s.volume!.toString();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✨ Sugerencia de IA aplicada a los campos')),
    );
  }

  String _buildCoverUrl() {
    if (widget.volume.coverUrl == null || widget.volume.coverUrl!.isEmpty) return '';
    if (widget.volume.coverUrl!.startsWith('http')) return widget.volume.coverUrl!;
    final cleanBase = widget.baseUrl.replaceAll(RegExp(r"/+$"), "");
    final cleanPath = widget.volume.coverUrl!.startsWith('/') ? widget.volume.coverUrl! : '/${widget.volume.coverUrl!}';
    return '$cleanBase$cleanPath';
  }

  Future<void> _handleSave() async {
    final cubit = context.read<ZeepubEditorialCubit>();
    final volNum = double.tryParse(_volumeController.text.trim());

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'spanish_title': _spanishTitleController.text.trim(),
      'english_title': _englishTitleController.text.trim(),
      'volume': volNum,
      'edition': _editionController.text.trim(),
      'color_mode': _colorMode,
      'is_uncensored': _isUncensored,
      'author': _authorController.text.trim(),
      'illustrator': _illustratorController.text.trim(),
      'translator': _translatorController.text.trim(),
      'layout_by': _layoutByController.text.trim(),
      'publisher': _publisherController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    final ok = await cubit.saveVolume(widget.volume.bookHash, payload);
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final coverUrl = _buildCoverUrl();

    return BlocConsumer<ZeepubEditorialCubit, ZeepubEditorialState>(
      listener: (BuildContext context, ZeepubEditorialState state) {
        if (state.latestAiSuggestion != null) {
          _applyAiSuggestion(state);
        }
      },
      builder: (BuildContext context, ZeepubEditorialState state) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header
                  Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 80,
                          color: cs.surfaceContainerHighest,
                          child: coverUrl.isNotEmpty
                              ? Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(Icons.menu_book, color: cs.primary),
                                )
                              : Icon(Icons.menu_book, color: cs.primary),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editar Volumen',
                              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.volume.filename ?? widget.volume.title,
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // AI Suggest Button
                      FilledButton.tonalIcon(
                        icon: state.aiLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Sugerir con IA'),
                        onPressed: state.aiLoading
                            ? null
                            : () {
                                final query = _titleController.text.isNotEmpty
                                    ? _titleController.text
                                    : (widget.volume.filename ?? widget.volume.title);
                                context.read<ZeepubEditorialCubit>().requestAiSuggestion(query);
                              },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 1: Titles & Volume
                          Text('Títulos y Volumen', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _spanishTitleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Título en Español (Canónico) *',
                                    hintText: 'Ej. Mi Vecina el Ángel me Está Malcriando',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _volumeController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Volumen # *',
                                    hintText: 'Ej. 1, 2, 8.5',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _englishTitleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Título en Inglés / Romaji',
                                    hintText: 'Ej. The Angel Next Door Spoils Me Rotten',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _editionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Edición especial (Opcional)',
                                    hintText: 'Ej. Edición Especial, SS, BD',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Título Original del Archivo',
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Section 2: Formato y Modos
                          Text('Formato & Contenido', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'bw',
                                      label: Text('B/N Estándar'),
                                      icon: Icon(Icons.chrome_reader_mode_outlined),
                                    ),
                                    ButtonSegment(
                                      value: 'color',
                                      label: Text('Full Color'),
                                      icon: Icon(Icons.palette_outlined),
                                    ),
                                  ],
                                  selected: {_colorMode},
                                  onSelectionChanged: (set) {
                                    setState(() {
                                      _colorMode = set.first;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Versión Sin Censura'),
                                  subtitle: const Text('Ilustraciones / Contenido explícito'),
                                  value: _isUncensored,
                                  onChanged: (val) {
                                    setState(() {
                                      _isUncensored = val ?? false;
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Section 3: Fansub & Créditos
                          Text('Créditos & Fansub', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Fansub Autocomplete / Dropdown
                              Expanded(
                                flex: 2,
                                child: Autocomplete<ZeepubWorkgroup>(
                                  initialValue: TextEditingValue(text: _publisherController.text),
                                  displayStringForOption: (option) => option.displayName,
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return widget.workgroups;
                                    }
                                    return widget.workgroups.where((g) =>
                                        g.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                        g.siglas.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (option) {
                                    _publisherController.text = option.name;
                                  },
                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                    textEditingController.addListener(() {
                                      _publisherController.text = textEditingController.text;
                                    });
                                    return TextField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Grupo Traductor / Fansub (Publisher) *',
                                        hintText: 'Seleccionar o escribir nombre',
                                        prefixIcon: Icon(Icons.business_outlined),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _translatorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Traductor individual',
                                    hintText: 'Ej. Mark, Onigiri',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _layoutByController,
                                  decoration: const InputDecoration(
                                    labelText: 'Maquetador',
                                    hintText: 'Ej. Saosora',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _authorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Autor',
                                    hintText: 'Ej. Saeki-san',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _illustratorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ilustrador',
                                    hintText: 'Ej. Hanekoto',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Section 4: Sinopsis
                          Text('Sinopsis & Descripción', style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Sinopsis del volumen',
                              hintText: 'Argumento del tomo...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Re-escanear EPUB en disco'),
                        onPressed: state.saving
                            ? null
                            : () => context.read<ZeepubEditorialCubit>().syncVolumeFromDisk(widget.volume.bookHash),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: state.saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: state.saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Guardar Metadatos'),
                        onPressed: state.saving ? null : _handleSave,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
