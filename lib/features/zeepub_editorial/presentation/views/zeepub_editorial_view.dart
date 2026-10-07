import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_cubit.dart';
import '/features/zeepub_editorial/presentation/cubit/zeepub_editorial_state.dart';
import 'widgets/series_list_widget.dart';
import 'widgets/telegram_publish_dialog.dart';
import 'widgets/volume_card.dart';
import 'zeepub_volume_edit_view.dart';

class ZeepubEditorialView extends StatefulWidget {
  const ZeepubEditorialView({super.key});

  @override
  State<ZeepubEditorialView> createState() => _ZeepubEditorialViewState();
}

class _ZeepubEditorialViewState extends State<ZeepubEditorialView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ZeepubEditorialCubit>().init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showConfigServerDialog(BuildContext context, String currentUrl) {
    final urlCtrl = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_rounded),
            SizedBox(width: 8),
            Text('Conexión con ZeePub Bot'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa la URL del backend de ZeePub (local o VPS).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL Base del Servidor',
                hintText: 'http://localhost:8001 o https://zeepubs.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                context.read<ZeepubEditorialCubit>().updateBaseUrl(newUrl);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar y Reconectar'),
          ),
        ],
      ),
    );
  }

  void _openPublishModal(BuildContext context, ZeepubVolume volume, ZeepubEditorialState state) {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<ZeepubEditorialCubit>(),
        child: TelegramPublishDialog(
          volume: volume,
          baseUrl: state.baseUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<ZeepubEditorialCubit, ZeepubEditorialState>(
      listener: (BuildContext context, ZeepubEditorialState state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.error,
              content: Text(state.errorMessage!),
            ),
          );
          context.read<ZeepubEditorialCubit>().clearNotifications();
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade700,
              content: Text(state.successMessage!),
            ),
          );
          context.read<ZeepubEditorialCubit>().clearNotifications();
        }
      },
      builder: (BuildContext context, ZeepubEditorialState state) {
        final cubit = context.read<ZeepubEditorialCubit>();

        // FULL PAGE EDITOR: If an active volume is selected, render full-page editor
        if (state.activeVolume != null) {
          return ZeepubVolumeEditView(
            volume: state.activeVolume!,
            workgroups: state.workgroups,
            baseUrl: state.baseUrl,
            onBack: () => cubit.closeVolumeDetail(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.auto_stories_rounded),
                const SizedBox(width: 10),
                const Text('Consola Editorial ZeePub'),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: state.errorMessage != null ? Colors.red : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.baseUrl.replaceFirst('http://', '').replaceFirst('https://', ''),
                        style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_ethernet),
                tooltip: 'Configurar URL del servidor',
                onPressed: () => _showConfigServerDialog(context, state.baseUrl),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar datos',
                onPressed: state.loading ? null : () => cubit.init(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.library_books),
                  text: 'Volúmenes (${state.totalVolumes})',
                ),
                Tab(
                  icon: const Icon(Icons.category),
                  text: 'Series Canónicas (${state.totalSeries})',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: VOLUMES
              Column(
                children: [
                  // Search & Filters Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar por título, serie, autor, traductor, archivo...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            cubit.setSearchQuery('');
                                          },
                                        )
                                      : null,
                                ),
                                onSubmitted: (val) => cubit.setSearchQuery(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => cubit.setSearchQuery(_searchController.text),
                              child: const Text('Buscar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Filters Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Color Filter
                              FilterChip(
                                label: const Text('Todos los colores'),
                                selected: state.selectedColorMode == null,
                                onSelected: (_) => cubit.setColorFilter(null),
                              ),
                              const SizedBox(width: 6),
                              FilterChip(
                                label: const Text('🎨 Full Color'),
                                selected: state.selectedColorMode == 'color',
                                onSelected: (val) => cubit.setColorFilter(val ? 'color' : null),
                              ),
                              const SizedBox(width: 6),
                              FilterChip(
                                label: const Text('📖 B/N'),
                                selected: state.selectedColorMode == 'bw',
                                onSelected: (val) => cubit.setColorFilter(val ? 'bw' : null),
                              ),
                              const SizedBox(width: 12),

                              // Uncensored Filter
                              FilterChip(
                                label: const Text('🔞 Sin Censura'),
                                selected: state.filterUncensored == true,
                                onSelected: (val) => cubit.setUncensoredFilter(val ? true : null),
                              ),
                              const SizedBox(width: 12),

                              // Clear filters button
                              if (state.selectedColorMode != null ||
                                  state.filterUncensored != null ||
                                  state.selectedWorkgroupId != null ||
                                  state.searchQuery.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.filter_alt_off, size: 16),
                                  label: const Text('Limpiar filtros'),
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.loadVolumes(page: 1, query: '', colorMode: null, uncensored: null, workgroupId: null);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Volumes Content
                  Expanded(
                    child: state.loading
                        ? const Center(child: CircularProgressIndicator())
                        : state.volumes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_outlined, size: 48, color: cs.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No se encontraron volúmenes',
                                      style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prueba ajustando los filtros o realizando otra búsqueda.',
                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount = constraints.maxWidth > 1100
                                      ? 3
                                      : constraints.maxWidth > 700
                                          ? 2
                                          : 1;

                                  return GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: 2.5,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: state.volumes.length,
                                    itemBuilder: (context, index) {
                                      final vol = state.volumes[index];
                                      return VolumeCard(
                                        volume: vol,
                                        baseUrl: state.baseUrl,
                                        onEdit: () => cubit.openVolumeDetail(vol.bookHash),
                                        onPublish: () => _openPublishModal(context, vol, state),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),

                  // Pagination Footer
                  if (state.totalPages > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Página ${state.currentPage} de ${state.totalPages} (${state.totalVolumes} volúmenes)',
                            style: tt.bodySmall,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: state.currentPage > 1
                                    ? () => cubit.loadVolumes(page: state.currentPage - 1)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: state.currentPage < state.totalPages
                                    ? () => cubit.loadVolumes(page: state.currentPage + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // TAB 2: CANONICAL SERIES
              SeriesListWidget(baseUrl: state.baseUrl),
            ],
          ),
        );
      },
    );
  }
}
