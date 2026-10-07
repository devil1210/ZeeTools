import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/utils/input_formatters.dart';
import '/common/utils/uuid_v7.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/toggle_field.dart';
import '/features/epub_templater/domain/subjects.dart';
import '/features/epub_templater/domain/title_languages.dart';
import '/features/epub_templater/presentation/views/widgets/form_fields.dart';
import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/data/models/zeepub_workgroup.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_cubit.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_state.dart';
import 'widgets/telegram_publish_dialog.dart';

class ZeepubVolumeEditView extends StatefulWidget {
  final ZeepubVolume volume;
  final List<ZeepubWorkgroup> workgroups;
  final String baseUrl;
  final VoidCallback onBack;

  const ZeepubVolumeEditView({
    super.key,
    required this.volume,
    required this.workgroups,
    required this.baseUrl,
    required this.onBack,
  });

  @override
  State<ZeepubVolumeEditView> createState() => _ZeepubVolumeEditViewState();
}

class _ZeepubVolumeEditViewState extends State<ZeepubVolumeEditView> {
  // Identifiers
  late String _asin;
  late String _isbn13;
  late String _isbn10;
  late String _originalSource;
  late String _identifier;

  // Series & Title
  OriginalLanguage? _originalLanguage;
  late bool _isStandalone;
  late String _series;
  late String _seriesSpanish;
  late String _seriesEnglish;
  late String _seriesRomaji;
  late String _seriesNative;
  late String _volumeNumber;
  late String _title;
  late String _titleSpanish;
  late String _titleEnglish;
  late String _titleRomaji;
  late String _titleNative;
  late String _titleSort;

  // People & Credits
  late String _author;
  late String _authorNative;
  late String _illustrator;
  late String _illustratorNative;
  late String _translator;
  late String _workgroup;
  late String _layoutBy;
  late String _publisher;
  late String _webLinkLabel;
  late String _webLinkText;
  late String _webLinkUrl;

  // Publication
  late String _bookLanguage;
  late String _bookType;
  late String _publishDate;
  late String _description;

  // Classification
  String? _demographic;
  final Set<String> _selectedGenres = {};
  late String _colorMode;
  late bool _isUncensored;
  int? _rating;

  @override
  void initState() {
    super.initState();
    final v = widget.volume;

    _asin = '';
    _isbn13 = '';
    _isbn10 = '';
    _originalSource = '';
    _identifier = v.bookHash.isNotEmpty ? v.bookHash : uuidV7();

    _originalLanguage = OriginalLanguage.ja;
    _isStandalone = v.volume == null && (v.edition ?? '').toLowerCase().contains('único');
    _series = v.seriesName ?? '';
    _seriesSpanish = v.spanishTitle.isNotEmpty ? v.spanishTitle : (v.seriesName ?? '');
    _seriesEnglish = v.englishTitle.isNotEmpty ? v.englishTitle : '';
    _seriesRomaji = '';
    _seriesNative = '';
    _volumeNumber = v.volume != null ? (v.volume! % 1 == 0 ? v.volume!.toInt().toString() : v.volume!.toString()) : '';
    _title = v.title;
    _titleSpanish = v.spanishTitle;
    _titleEnglish = v.englishTitle;
    _titleRomaji = '';
    _titleNative = '';
    _titleSort = '';

    _author = v.author ?? '';
    _authorNative = '';
    _illustrator = v.illustrator ?? '';
    _illustratorNative = '';
    _translator = v.translator ?? '';
    _workgroup = v.workgroupName ?? '';
    _layoutBy = v.layoutBy ?? '';
    _publisher = v.publisher ?? '';
    _webLinkLabel = 'Página Web';
    _webLinkText = 'ZeePub';
    _webLinkUrl = 'https://t.me/ZeePubs';

    _bookLanguage = 'es';
    _bookType = 'Novela ligera';
    _publishDate = '';
    _description = v.description ?? '';

    _demographic = 'General';
    _colorMode = v.colorMode ?? ((v.filename ?? '').toLowerCase().contains('[color]') ? 'color' : 'bw');
    _isUncensored = v.isUncensored;
    _rating = null;
  }

  void _applyAiSuggestion(ZeepubEditorialState state) {
    final s = state.latestAiSuggestion;
    if (s == null) return;
    setState(() {
      if (s.spanishTitle.isNotEmpty) {
        _titleSpanish = s.spanishTitle;
        _seriesSpanish = s.spanishTitle;
      }
      if (s.englishTitle.isNotEmpty) {
        _titleEnglish = s.englishTitle;
        _seriesEnglish = s.englishTitle;
      }
      if (s.author.isNotEmpty) {
        _author = s.author;
      }
      if (s.volume != null) {
        _volumeNumber = s.volume! % 1 == 0 ? s.volume!.toInt().toString() : s.volume!.toString();
      }
      if (s.demography.isNotEmpty) {
        _demographic = s.demography;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('✨ Sugerencia de IA aplicada a los campos'),
      ),
    );
  }

  String _buildCoverUrl() {
    if (widget.volume.coverUrl == null || widget.volume.coverUrl!.isEmpty) return '';
    if (widget.volume.coverUrl!.startsWith('http')) return widget.volume.coverUrl!;
    final cleanBase = widget.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = widget.volume.coverUrl!.startsWith('/') ? widget.volume.coverUrl! : '/${widget.volume.coverUrl!}';
    return '$cleanBase$cleanPath';
  }

  Future<void> _handleSave() async {
    final cubit = context.read<ZeepubEditorialCubit>();
    final volNum = _isStandalone ? null : double.tryParse(_volumeNumber.trim());

    final payload = <String, dynamic>{
      'title': _title.trim().isNotEmpty ? _title.trim() : _titleSpanish.trim(),
      'spanish_title': _titleSpanish.trim(),
      'english_title': _titleEnglish.trim(),
      'volume': volNum,
      'edition': _isStandalone ? 'Volumen Único' : (widget.volume.edition ?? ''),
      'color_mode': _colorMode,
      'is_uncensored': _isUncensored,
      'author': _author.trim(),
      'illustrator': _illustrator.trim(),
      'translator': _translator.trim(),
      'layout_by': _layoutBy.trim(),
      'publisher': _publisher.trim().isNotEmpty ? _publisher.trim() : _workgroup.trim(),
      'description': _description.trim(),
      'demography': _demographic ?? 'General',
    };

    await cubit.saveVolume(widget.volume.bookHash, payload);
  }

  void _openPublishDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<ZeepubEditorialCubit>(),
        child: TelegramPublishDialog(
          volume: widget.volume,
          baseUrl: widget.baseUrl,
        ),
      ),
    );
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
        final cubit = context.read<ZeepubEditorialCubit>();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver a la lista de volúmenes',
              onPressed: widget.onBack,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editor de Metadatos de Volumen',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.volume.filename ?? widget.volume.title,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              FilledButton.tonalIcon(
                icon: state.aiLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Completar con IA'),
                onPressed: state.aiLoading
                    ? null
                    : () {
                        final searchTitle = _titleSpanish.isNotEmpty
                            ? _titleSpanish
                            : (_series.isNotEmpty ? _series : widget.volume.title);
                        cubit.requestAiSuggestion(searchTitle);
                      },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Publicar en Telegram',
                onPressed: _openPublishDialog,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: state.saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar Metadatos'),
                onPressed: state.saving ? null : _handleSave,
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL: Cover, File Details & Quick Actions
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppPadding.large),
                  children: [
                    // High-res Cover
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 210,
                          height: 300,
                          color: cs.surfaceContainerHighest,
                          child: coverUrl.isNotEmpty
                              ? Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(Icons.menu_book_rounded, size: 64, color: cs.primary),
                                  ),
                                )
                              : Center(
                                  child: Icon(Icons.menu_book_rounded, size: 64, color: cs.primary),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // File Information Section
                    FormSection(
                      title: 'Archivo y Servidor',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Hash del Libro:\n${widget.volume.bookHash}',
                                style: tt.labelSmall?.copyWith(fontFamily: 'monospace', color: cs.onSurfaceVariant),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar Hash',
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.volume.bookHash));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Hash copiado al portapapeles')),
                                );
                              },
                            ),
                          ],
                        ),
                        if (widget.volume.fileSize != null)
                          Text(
                            'Tamaño: ${(widget.volume.fileSize! / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: tt.bodySmall,
                          ),
                        if (widget.volume.filepath != null)
                          Text(
                            'Ruta en Servidor:\n${widget.volume.filepath}',
                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Re-escanear EPUB en disco'),
                          onPressed: state.saving
                              ? null
                              : () => cubit.syncVolumeFromDisk(widget.volume.bookHash),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // RIGHT PANEL: Comprehensive Metadata Editor Form (matching ZeeTools MetadataForm)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, 96),
                  children: [
                    // SECTION 1: IDENTIFICADORES
                    FormSection(
                      title: 'Identificadores',
                      children: [
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'ASIN de Amazon',
                              value: _asin,
                              hint: 'B0XXXXXXXX',
                              onChanged: (v) => setState(() => _asin = v.trim().toUpperCase()),
                            ),
                            AppTextField(
                              label: 'ISBN-13',
                              value: _isbn13,
                              hint: '978-XX-XXXX-XXX-X',
                              inputFormatters: [isbnFormatter(isbn13Groups)],
                              error: _isbn13.trim().isNotEmpty && !isValidIsbn13(_isbn13) ? 'ISBN-13 no válido' : null,
                              onChanged: (v) => setState(() {
                                _isbn13 = v;
                                if (isbn10From13(v) case final ten? when _isbn10.trim().isEmpty) {
                                  _isbn10 = formatIsbn(ten, isbn10Groups);
                                }
                              }),
                            ),
                            AppTextField(
                              label: 'ISBN-10',
                              value: _isbn10,
                              hint: 'XX-XXXX-XXX-X',
                              inputFormatters: [isbnFormatter(isbn10Groups)],
                              error: _isbn10.trim().isNotEmpty && !isValidIsbn10(_isbn10) ? 'ISBN-10 no válido' : null,
                              onChanged: (v) => setState(() {
                                _isbn10 = v;
                                if (isbn13From10(v) case final thirteen? when _isbn13.trim().isEmpty) {
                                  _isbn13 = formatIsbn(thirteen, isbn13Groups);
                                }
                              }),
                            ),
                          ],
                        ),
                        AppTextField(
                          label: 'Publicación original (Web Novel)',
                          value: _originalSource,
                          hint: 'https://ncode.syosetu.com/nXXXXXX',
                          helper: 'Página donde se publicó la novela web original.',
                          onChanged: (v) => setState(() => _originalSource = v.trim()),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Identificador único (UUID)'),
                                child: SelectableText('urn:uuid:$_identifier'),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar Identificador',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () => Clipboard.setData(ClipboardData(text: 'urn:uuid:$_identifier')),
                            ),
                            IconButton(
                              tooltip: 'Generar nuevo UUID',
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: () => setState(() => _identifier = uuidV7()),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // SECTION 2: SERIE Y TÍTULO
                    FormSection(
                      title: 'Serie y título',
                      children: [
                        OutlinedDropdown<OriginalLanguage?>(
                          label: 'Idioma en que se escribió la obra',
                          value: _originalLanguage,
                          helper: switch (_originalLanguage) {
                            OriginalLanguage.es => 'El título y la serie principales van en español; en inglés son opcionales.',
                            OriginalLanguage(scripted: true) => 'Añade el título y la serie romanizados y en su escritura nativa.',
                            _ => null,
                          },
                          onChanged: (v) => setState(() => _originalLanguage = v),
                          items: [
                            for (final o in OriginalLanguage.values)
                              DropdownMenuItem(value: o, child: Text(o.label)),
                          ],
                        ),
                        ToggleField(
                          label: 'Volumen único',
                          value: _isStandalone,
                          helper: 'No pertenece a ninguna serie continua: no lleva serie ni número de volumen.',
                          onChanged: (v) => setState(() {
                            _isStandalone = v;
                            if (v) _volumeNumber = '';
                          }),
                        ),
                        if (!_isStandalone) ...[
                          ResponsiveRow(
                            widths: const [null, numberColumnWidth],
                            children: [
                              AppTextField(
                                label: 'Serie en español / principal',
                                value: _seriesSpanish.isNotEmpty ? _seriesSpanish : _series,
                                hint: 'Nombre de la Serie',
                                onChanged: (v) => setState(() {
                                  _seriesSpanish = v;
                                  if (_titleSpanish.isEmpty || _titleSpanish.startsWith(_series)) {
                                    _titleSpanish = v;
                                  }
                                }),
                              ),
                              AppTextField(
                                label: 'Volumen',
                                value: _volumeNumber,
                                hint: '1, 2, 3.5',
                                inputFormatters: [decimalNumberFormatter],
                                onChanged: (v) => setState(() => _volumeNumber = v),
                              ),
                            ],
                          ),
                          ResponsiveRow(
                            children: [
                              AppTextField(
                                label: 'Serie en inglés',
                                value: _seriesEnglish,
                                hint: 'English Series Name',
                                onChanged: (v) => setState(() => _seriesEnglish = v),
                              ),
                              if (_originalLanguage != null && _originalLanguage!.scripted) ...[
                                AppTextField(
                                  label: 'Serie en ${_originalLanguage!.romanization}',
                                  value: _seriesRomaji,
                                  hint: 'Romaji / Romanizado',
                                  onChanged: (v) => setState(() => _seriesRomaji = v),
                                ),
                                AppTextField(
                                  label: 'Serie en ${_originalLanguage!.label.toLowerCase()}',
                                  value: _seriesNative,
                                  hint: 'Caracteres nativos (Kanji/Hangul/Hanzi)',
                                  onChanged: (v) => setState(() => _seriesNative = v),
                                ),
                              ],
                            ],
                          ),
                        ],
                        AppTextField(
                          label: 'Título en español / principal',
                          value: _titleSpanish.isNotEmpty ? _titleSpanish : _title,
                          hint: 'Nombre de la novela - Volumen 01 [SIGLAS]',
                          onChanged: (v) => setState(() => _titleSpanish = v),
                        ),
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Título en inglés',
                              value: _titleEnglish,
                              hint: 'English Title',
                              onChanged: (v) => setState(() => _titleEnglish = v),
                            ),
                            if (_originalLanguage != null && _originalLanguage!.scripted) ...[
                              AppTextField(
                                label: 'Título en ${_originalLanguage!.romanization}',
                                value: _titleRomaji,
                                hint: 'Romaji / Romanizado',
                                onChanged: (v) => setState(() => _titleRomaji = v),
                              ),
                              AppTextField(
                                label: 'Título en ${_originalLanguage!.label.toLowerCase()}',
                                value: _titleNative,
                                hint: 'Caracteres nativos (Kanji/Hangul/Hanzi)',
                                onChanged: (v) => setState(() => _titleNative = v),
                              ),
                            ],
                          ],
                        ),
                        AppTextField(
                          label: 'Título para ordenar (Opcional)',
                          value: _titleSort,
                          hint: 'Titulo para ordenar alfabeticamente',
                          onChanged: (v) => setState(() => _titleSort = v),
                        ),
                      ],
                    ),

                    // SECTION 3: PERSONAS Y CRÉDITOS
                    FormSection(
                      title: 'Personas y Créditos',
                      children: [
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Autor (Romaji / Alfabético)',
                              value: _author,
                              hint: 'Ej. Meguru Seto, Fuse, Rifujin na Magonote',
                              onChanged: (v) => setState(() => _author = v),
                            ),
                            AppTextField(
                              label: 'Autor (Escritura nativa)',
                              value: _authorNative,
                              hint: 'Ej. 瀬戸メグル, 理不尽な孫の手',
                              onChanged: (v) => setState(() => _authorNative = v),
                            ),
                          ],
                        ),
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Ilustrador (Romaji / Alfabético)',
                              value: _illustrator,
                              hint: 'Ej. Takehana Note, Mitz Vah, Shirotaka',
                              onChanged: (v) => setState(() => _illustrator = v),
                            ),
                            AppTextField(
                              label: 'Ilustrador (Escritura nativa)',
                              value: _illustratorNative,
                              hint: 'Ej. 竹花ノート, みっつばー',
                              onChanged: (v) => setState(() => _illustratorNative = v),
                            ),
                          ],
                        ),
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Traductor individual',
                              value: _translator,
                              hint: 'Ej. Hitsugaya Rin, Onigiri, SkyTheWood',
                              onChanged: (v) => setState(() => _translator = v),
                            ),
                            Autocomplete<String>(
                              initialValue: TextEditingValue(text: _workgroup),
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return widget.workgroups.map((w) => w.name);
                                }
                                return widget.workgroups
                                    .map((w) => w.name)
                                    .where((name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              },
                              onSelected: (selection) => setState(() => _workgroup = selection),
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Grupo / Fansub (ZeePub Workgroup)',
                                    hintText: 'Ej. NovelZ, Saosora Scan, Einherjar',
                                    prefixIcon: Icon(Icons.groups_rounded),
                                  ),
                                  onChanged: (v) => setState(() => _workgroup = v),
                                );
                              },
                            ),
                          ],
                        ),
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Maquetador / Layout by',
                              value: _layoutBy,
                              hint: 'Ej. Devil_1210, Saosora, ZeePub Staff',
                              onChanged: (v) => setState(() => _layoutBy = v),
                            ),
                            AppTextField(
                              label: 'Editorial original / Publicador',
                              value: _publisher,
                              hint: 'Ej. Kadokawa Sneaker Bunko, MF Bunko J, Overlap Bunko',
                              onChanged: (v) => setState(() => _publisher = v),
                            ),
                          ],
                        ),
                        ResponsiveRow(
                          children: [
                            AppTextField(
                              label: 'Etiqueta de enlace',
                              value: _webLinkLabel,
                              hint: 'Página Web',
                              onChanged: (v) => setState(() => _webLinkLabel = v),
                            ),
                            AppTextField(
                              label: 'Texto del enlace',
                              value: _webLinkText,
                              hint: 'ZeePub Bot',
                              onChanged: (v) => setState(() => _webLinkText = v),
                            ),
                            AppTextField(
                              label: 'URL de referencia',
                              value: _webLinkUrl,
                              hint: 'https://t.me/ZeePubs',
                              onChanged: (v) => setState(() => _webLinkUrl = v.trim()),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // SECTION 4: PUBLICACIÓN Y FORMATO
                    FormSection(
                      title: 'Publicación',
                      children: [
                        ResponsiveRow(
                          children: [
                            OutlinedDropdown<String>(
                              label: 'Idioma del libro',
                              value: _bookLanguage,
                              onChanged: (v) {
                                if (v != null) setState(() => _bookLanguage = v);
                              },
                              items: [
                                for (final MapEntry(key: code, value: name) in bookLanguages.entries)
                                  DropdownMenuItem(value: code, child: Text(name)),
                              ],
                            ),
                            OutlinedDropdown<String>(
                              label: 'Tipo de libro',
                              value: _bookType,
                              onChanged: (v) {
                                if (v != null) setState(() => _bookType = v);
                              },
                              items: const [
                                DropdownMenuItem(value: 'Novela ligera', child: Text('Novela ligera')),
                                DropdownMenuItem(value: 'Novela web', child: Text('Novela web')),
                                DropdownMenuItem(value: 'Novela', child: Text('Novela')),
                                DropdownMenuItem(value: 'Manga', child: Text('Manga')),
                                DropdownMenuItem(value: 'Manhwa', child: Text('Manhwa')),
                                DropdownMenuItem(value: 'Manhua', child: Text('Manhua')),
                                DropdownMenuItem(value: 'Cómic', child: Text('Cómic')),
                              ],
                            ),
                            AppTextField(
                              label: 'Fecha de publicación',
                              value: _publishDate,
                              hint: 'YYYY-MM-DD',
                              onChanged: (v) => setState(() => _publishDate = v),
                            ),
                          ],
                        ),
                        AppTextField(
                          label: 'Sinopsis / Argumento',
                          value: _description,
                          hint: 'Escribe o pega aquí la sinopsis completa de la obra...',
                          maxLines: 12,
                          onChanged: (v) => setState(() => _description = v),
                        ),
                      ],
                    ),

                    // SECTION 5: CLASIFICACIÓN
                    FormSection(
                      title: 'Clasificación',
                      children: [
                        Text('Demografía', style: tt.labelLarge),
                        Wrap(
                          spacing: AppSpacing.medium,
                          runSpacing: AppSpacing.small,
                          children: [
                            for (final d in Demographic.values)
                              SelectionPill(
                                tooltip: 'Añade también «${d.ageGroup}»',
                                selected: _demographic == d.name || _demographic == d.label,
                                onTap: () => setState(() {
                                  _demographic = _demographic == d.name ? null : d.name;
                                }),
                                child: Text(d.label),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Géneros Literarios', style: tt.labelLarge),
                        Wrap(
                          spacing: AppSpacing.medium,
                          runSpacing: AppSpacing.small,
                          children: [
                            for (final genre in literaryGenres)
                              SelectionPill(
                                selected: _selectedGenres.contains(genre),
                                onTap: () => setState(() {
                                  if (_selectedGenres.contains(genre)) {
                                    _selectedGenres.remove(genre);
                                  } else {
                                    _selectedGenres.add(genre);
                                  }
                                }),
                                child: Text(genre),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Características de Edición', style: tt.labelLarge),
                        Wrap(
                          spacing: AppSpacing.medium,
                          runSpacing: AppSpacing.small,
                          children: [
                            SelectionPill(
                              selected: _colorMode == 'color',
                              onTap: () => setState(() {
                                _colorMode = _colorMode == 'color' ? 'bw' : 'color';
                              }),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.palette_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text('A color'),
                                ],
                              ),
                            ),
                            SelectionPill(
                              selected: _isUncensored,
                              onTap: () => setState(() {
                                _isUncensored = !_isUncensored;
                              }),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_open_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text('Sin censura'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedDropdown<int?>(
                          label: 'Calificación de Calibre',
                          value: _rating,
                          onChanged: (v) => setState(() => _rating = v),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Sin calificar')),
                            for (var r = 1; r <= 10; r++)
                              DropdownMenuItem(
                                value: r,
                                child: Text('${'★' * (r ~/ 2)}${r.isOdd ? '⯨' : ''}'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
