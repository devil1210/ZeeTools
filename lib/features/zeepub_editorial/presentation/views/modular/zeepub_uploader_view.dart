import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/utils/either.dart';
import '/features/epub_templater/domain/book_metadata.dart';
import '/features/metadata_editor/data/epub_metadata_repo.dart';
import '/features/zeepub_editorial/data/models/zeepub_series.dart';
import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_cubit.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_state.dart';
import '/inject_dependencies.dart';
import '../widgets/zeepub_server_config_dialog.dart';
import 'widgets/epub_metadata_validator_card.dart';
import 'widgets/series_destination_selector.dart';

/// Vista modular del Subidor / Vinculador de EPUBs de ZeePub.
///
/// Permite seleccionar un archivo EPUB local, auditar y validar sus metadatos
/// internos con calidad editorial, calcular su hash SHA-256 y asociarlo
/// a una serie existente o dar de alta una nueva serie en el backend.
class ZeepubUploaderView extends StatefulWidget {
  const ZeepubUploaderView({super.key});

  @override
  State<ZeepubUploaderView> createState() => _ZeepubUploaderViewState();
}

class _ZeepubUploaderViewState extends State<ZeepubUploaderView> {
  String? _selectedFilePath;
  String? _fileName;
  int _fileSizeBytes = 0;
  String? _sha256Hash;
  bool _isProcessing = false;
  String? _parseError;

  BookMetadata? _parsedMetadata;

  // Modo de Destino
  bool _isCreatingNewSeries = false;

  // Modo Existente
  ZeepubSeries? _selectedSeries;
  ZeepubVolume? _selectedVolume;

  // Modo Nueva Serie Controllers
  final _newSeriesNameController = TextEditingController();
  final _newSeriesSpanishController = TextEditingController();
  final _newSeriesAuthorController = TextEditingController();
  final _newSeriesPublisherController = TextEditingController();
  final _newSeriesVolumeNumberController = TextEditingController(text: '1');
  final _newSeriesVolumeTitleController = TextEditingController();
  final _newSeriesDescController = TextEditingController();
  String _selectedBookType = 'Novela Ligera';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<ZeepubEditorialCubit>();
      if (cubit.state.seriesList.isEmpty) {
        cubit.init();
      }
    });
  }

  @override
  void dispose() {
    _newSeriesNameController.dispose();
    _newSeriesSpanishController.dispose();
    _newSeriesAuthorController.dispose();
    _newSeriesPublisherController.dispose();
    _newSeriesVolumeNumberController.dispose();
    _newSeriesVolumeTitleController.dispose();
    _newSeriesDescController.dispose();
    super.dispose();
  }

  Future<void> _pickEpubFile() async {
    try {
      final path = (await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub'],
        dialogTitle: 'Selecciona un archivo EPUB',
        windowsOptions: const WindowsOptions(lockParentWindow: true),
      )).map((f) => f.path).whereType<String>().firstOrNull;

      if (path == null) return;

      setState(() {
        _isProcessing = true;
        _parseError = null;
        _selectedFilePath = path;
        _fileName = path.split(Platform.pathSeparator).last;
      });

      // 1. Cálculo de hash y tamaño
      final file = File(path);
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      // 2. Extracción y Validación de Metadatos con EpubMetadataRepository
      final repo = getIt<EpubMetadataRepository>();
      final loadRes = await repo.load(path);

      BookMetadata? extractedMeta;
      String? loadErr;

      if (loadRes case Right(value: final meta)) {
        extractedMeta = meta;
        repo.unload(path);
      } else if (loadRes case Left(value: final err)) {
        loadErr = err;
        repo.unload(path);
      }

      setState(() {
        _fileSizeBytes = bytes.length;
        _sha256Hash = hash;
        _parsedMetadata = extractedMeta;
        _parseError = loadErr;
        _isProcessing = false;
      });

      // 3. Auto-rellenado inteligente de campos
      if (extractedMeta != null && mounted) {
        _applyIntelligentMatching(extractedMeta);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _parseError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leyendo el archivo EPUB: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _applyIntelligentMatching(BookMetadata meta) {
    final cubit = context.read<ZeepubEditorialCubit>();
    final seriesList = cubit.state.seriesList;

    final epubSeries = meta.series.trim();
    final epubAuthor = meta.actors.where((a) => a.isCreator || a.name.isNotEmpty).firstOrNull?.name ?? '';
    final epubPublisher = meta.publishers.isNotEmpty ? meta.publishers.first : '';
    final epubVolume = meta.seriesIndex.trim().isNotEmpty ? meta.seriesIndex.trim() : '1';
    final epubTitle = meta.title.trim();
    final epubDesc = meta.description.trim();

    // Buscar coincidencia en series existentes
    ZeepubSeries? matchedSeries;
    if (epubSeries.isNotEmpty) {
      matchedSeries = seriesList.where((s) {
        final normS = s.name.toLowerCase().trim();
        final normE = epubSeries.toLowerCase().trim();
        return normS == normE || s.seriesSpanish.toLowerCase().trim() == normE;
      }).firstOrNull;
    }

    if (matchedSeries != null) {
      // Coincidencia encontrada: asociar a la serie existente
      setState(() {
        _isCreatingNewSeries = false;
        _selectedSeries = matchedSeries;
        _selectedVolume = null;
      });
    } else {
      // No existe en catálogo: proponer crear nueva serie y pre-rellenar
      setState(() {
        _isCreatingNewSeries = true;
        _newSeriesNameController.text = epubSeries.isNotEmpty ? epubSeries : epubTitle;
        _newSeriesSpanishController.text = epubSeries.isNotEmpty ? epubSeries : epubTitle;
        _newSeriesAuthorController.text = epubAuthor;
        _newSeriesPublisherController.text = epubPublisher;
        _newSeriesVolumeNumberController.text = epubVolume;
        _newSeriesVolumeTitleController.text = epubTitle;
        _newSeriesDescController.text = epubDesc;
        if (meta.bookType.isNotEmpty) {
          _selectedBookType = meta.bookType;
        }
      });
    }
  }

  Future<void> _handleUploadAndSync(ZeepubEditorialCubit cubit) async {
    if (_isCreatingNewSeries) {
      // Modo: Crear nueva serie y registrar
      final name = _newSeriesNameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, ingresa el nombre de la nueva serie.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final seriesId = await cubit.createSeries(
        name: name,
        seriesSpanish: _newSeriesSpanishController.text.trim(),
        author: _newSeriesAuthorController.text.trim(),
        publisher: _newSeriesPublisherController.text.trim(),
        bookType: _selectedBookType,
        description: _newSeriesDescController.text.trim(),
      );

      if (seriesId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Serie "$name" creada exitosamente con ID: $seriesId'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      // Modo: Vincular a volumen existente
      if (_selectedVolume == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona una serie y un volumen de destino.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await cubit.syncVolumeFile(_selectedVolume!.bookHash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<ZeepubEditorialCubit, ZeepubEditorialState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: cs.error,
              action: SnackBarAction(
                label: 'OK',
                textColor: cs.onError,
                onPressed: () => context.read<ZeepubEditorialCubit>().clearNotifications(),
              ),
            ),
          );
          context.read<ZeepubEditorialCubit>().clearNotifications();
        }
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor: Colors.green.shade700,
            ),
          );
          context.read<ZeepubEditorialCubit>().clearNotifications();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ZeepubEditorialCubit>();

        final availableVolumes = _selectedSeries != null
            ? state.volumes.where((v) => v.seriesId == _selectedSeries!.id || v.seriesName == _selectedSeries!.name).toList()
            : state.volumes;

        final canSubmit = _selectedFilePath != null &&
            !state.saving &&
            (!_isCreatingNewSeries ? _selectedVolume != null : _newSeriesNameController.text.trim().isNotEmpty);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: Color(0xFF818CF8)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Subidor de EPUBs', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(
                      'Validación de metadatos, cálculo de hash y vinculación con ZeePub',
                      style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Ajustes del Servidor',
                onPressed: () => showZeepubServerConfigDialog(
                  context,
                  currentUrl: state.baseUrl,
                  currentTgId: state.telegramUserId,
                  currentScale: state.coverScale,
                  cubit: cubit,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Paso 1: Selección del archivo EPUB
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.file_present_rounded, color: Color(0xFF818CF8)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('1. Archivo EPUB Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    _selectedFilePath == null
                                        ? 'Selecciona el libro para analizar sus metadatos e integridad'
                                        : 'Archivo cargado para validación',
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              icon: const Icon(Icons.folder_open_rounded, size: 18),
                              label: Text(_selectedFilePath == null ? 'Elegir EPUB' : 'Cambiar EPUB'),
                              onPressed: _isProcessing ? null : _pickEpubFile,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Auditoría y Validación de Metadatos
                    EpubMetadataValidatorCard(
                      metadata: _parsedMetadata,
                      fileName: _fileName,
                      filePath: _selectedFilePath,
                      fileSizeBytes: _fileSizeBytes,
                      sha256Hash: _sha256Hash,
                      isProcessing: _isProcessing,
                      error: _parseError,
                    ),

                    const SizedBox(height: 18),

                    // Paso 2: Destino (Serie Existente o Nueva Serie)
                    SeriesDestinationSelector(
                      isCreatingNew: _isCreatingNewSeries,
                      onModeChanged: (val) => setState(() => _isCreatingNewSeries = val),
                      seriesList: state.seriesList,
                      selectedSeries: _selectedSeries,
                      onSeriesChanged: (val) => setState(() {
                        _selectedSeries = val;
                        _selectedVolume = null;
                      }),
                      availableVolumes: availableVolumes,
                      selectedVolume: _selectedVolume,
                      onVolumeChanged: (val) => setState(() => _selectedVolume = val),
                      newSeriesNameController: _newSeriesNameController,
                      newSeriesSpanishController: _newSeriesSpanishController,
                      newSeriesAuthorController: _newSeriesAuthorController,
                      newSeriesPublisherController: _newSeriesPublisherController,
                      newSeriesVolumeNumberController: _newSeriesVolumeNumberController,
                      newSeriesVolumeTitleController: _newSeriesVolumeTitleController,
                      newSeriesDescController: _newSeriesDescController,
                      selectedBookType: _selectedBookType,
                      onBookTypeChanged: (val) => setState(() => _selectedBookType = val),
                    ),

                    const SizedBox(height: 24),

                    // Botón de acción principal
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                      icon: state.saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(_isCreatingNewSeries ? Icons.add_task_rounded : Icons.sync_rounded),
                      label: Text(
                        state.saving
                            ? 'Procesando con ZeePub...'
                            : _isCreatingNewSeries
                                ? 'Dar de Alta Serie y Vincular EPUB'
                                : 'Vincular y Sincronizar EPUB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: canSubmit ? () => _handleUploadAndSync(cubit) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
