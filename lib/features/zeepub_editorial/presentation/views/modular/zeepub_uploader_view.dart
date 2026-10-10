import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/zeepub_editorial/data/models/zeepub_series.dart';
import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_cubit.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_state.dart';
import '../widgets/zeepub_server_config_dialog.dart';

/// Vista modular del Subidor / Vinculador de EPUBs de ZeePub.
///
/// Permite seleccionar un archivo EPUB local, calcular su hash SHA-256
/// y sincronizarlo directamente con el catálogo del backend de ZeePub.
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

  ZeepubSeries? _selectedSeries;
  ZeepubVolume? _selectedVolume;

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
        _selectedFilePath = path;
        _fileName = path.split(Platform.pathSeparator).last;
      });

      final file = File(path);
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      setState(() {
        _fileSizeBytes = bytes.length;
        _sha256Hash = hash;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _syncWithZeePub(ZeepubEditorialCubit cubit) async {
    if (_selectedVolume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una serie y un volumen de destino.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final targetVolume = _selectedVolume!;
    await cubit.syncVolumeFile(targetVolume.bookHash);
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

        // Filtro de volúmenes correspondientes a la serie seleccionada
        final availableVolumes = _selectedSeries != null
            ? state.volumes.where((v) => v.seriesId == _selectedSeries!.id || v.seriesName == _selectedSeries!.name).toList()
            : state.volumes;

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
                      'Vinculación de archivos locales con hash al backend ZeePub',
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
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Selección del archivo EPUB
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('1. Archivo EPUB Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Selecciona el libro generado o editado en ZeeTools', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ],
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                                  label: const Text('Elegir EPUB'),
                                  onPressed: _isProcessing ? null : _pickEpubFile,
                                ),
                              ],
                            ),
                            if (_isProcessing) ...[
                              const SizedBox(height: 20),
                              const Center(child: LinearProgressIndicator()),
                            ] else if (_selectedFilePath != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _fileName ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(_formatFileSize(_fileSizeBytes), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Ruta: $_selectedFilePath', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      'SHA-256: ${_sha256Hash ?? 'Calculando...'}',
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: const Color(0xFF38BDF8).withValues(alpha: 0.9)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 2: Destino en el catálogo ZeePub
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.link_rounded, color: Color(0xFF818CF8)),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('2. Vincular con Volumen en ZeePub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Elige la serie y el volumen para asociar el archivo', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<ZeepubSeries>(
                              initialValue: _selectedSeries,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Serie / Novela',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bookmark_outline),
                              ),
                              items: [
                                for (final s in state.seriesList)
                                  DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedSeries = val;
                                  _selectedVolume = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<ZeepubVolume>(
                              initialValue: _selectedVolume,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Volumen de destino',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.book_outlined),
                              ),
                              items: [
                                for (final v in availableVolumes)
                                  DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      'Vol. ${v.volume != null ? (v.volume! % 1 == 0 ? v.volume!.toInt() : v.volume) : "?"} - ${v.title.isNotEmpty ? v.title : (v.spanishTitle.isNotEmpty ? v.spanishTitle : "Sin título")} (${v.bookHash.substring(0, v.bookHash.length > 8 ? 8 : v.bookHash.length)})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (val) => setState(() => _selectedVolume = val),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card 3: Botón de acción
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                      icon: state.saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        state.saving ? 'Sincronizando con ZeePub...' : 'Vincular y Sincronizar EPUB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: (_selectedFilePath == null || _selectedVolume == null || state.saving)
                          ? null
                          : () => _syncWithZeePub(cubit),
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
