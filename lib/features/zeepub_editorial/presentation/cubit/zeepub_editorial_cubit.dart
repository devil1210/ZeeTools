import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/zeepub_editorial_repository.dart';
import 'zeepub_editorial_state.dart';

class ZeepubEditorialCubit extends Cubit<ZeepubEditorialState> {
  final ZeepubEditorialRepository _repo;

  ZeepubEditorialCubit(this._repo) : super(ZeepubEditorialState(baseUrl: _repo.getBaseUrl()));

  Future<void> init() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final workgroups = await _repo.getWorkgroups();
      final seriesRes = await _repo.getSeriesList(page: 1, pageSize: 100);
      final volumesRes = await _repo.getVolumes(page: 1, pageSize: 30);

      emit(state.copyWith(
        loading: false,
        baseUrl: _repo.getBaseUrl(),
        workgroups: workgroups,
        seriesList: seriesRes.items,
        totalSeries: seriesRes.total,
        volumes: volumesRes.items,
        totalVolumes: volumesRes.total,
        currentPage: volumesRes.page,
        totalPages: volumesRes.totalPages,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Error conectando con ZeePub Bot: $e',
      ));
    }
  }

  Future<void> updateBaseUrl(String url) async {
    await _repo.saveBaseUrl(url);
    emit(state.copyWith(baseUrl: _repo.getBaseUrl()));
    await init();
  }

  Future<void> loadVolumes({
    int? page,
    String? query,
    String? seriesId,
    int? workgroupId,
    String? colorMode,
    bool? uncensored,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    final targetPage = page ?? state.currentPage;
    final targetQuery = query ?? state.searchQuery;
    final targetSeries = seriesId ?? state.selectedSeriesId;
    final targetWorkgroup = workgroupId ?? state.selectedWorkgroupId;
    final targetColor = colorMode ?? state.selectedColorMode;
    final targetUncensored = uncensored ?? state.filterUncensored;

    try {
      final res = await _repo.getVolumes(
        page: targetPage,
        pageSize: 30,
        query: targetQuery,
        seriesId: targetSeries,
        workgroupId: targetWorkgroup,
        colorMode: targetColor,
        isUncensored: targetUncensored,
      );

      emit(state.copyWith(
        loading: false,
        volumes: res.items,
        totalVolumes: res.total,
        currentPage: res.page,
        totalPages: res.totalPages,
        searchQuery: targetQuery,
        selectedSeriesId: targetSeries,
        selectedWorkgroupId: targetWorkgroup,
        selectedColorMode: targetColor,
        filterUncensored: targetUncensored,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Error cargando volúmenes: $e',
      ));
    }
  }

  Future<void> setSearchQuery(String query) async {
    await loadVolumes(page: 1, query: query);
  }

  Future<void> setSeriesFilter(String? seriesId) async {
    emit(state.copyWith(selectedSeriesId: seriesId, clearSeriesFilter: seriesId == null));
    await loadVolumes(page: 1, seriesId: seriesId);
  }

  Future<void> setWorkgroupFilter(int? workgroupId) async {
    emit(state.copyWith(selectedWorkgroupId: workgroupId, clearWorkgroupFilter: workgroupId == null));
    await loadVolumes(page: 1, workgroupId: workgroupId);
  }

  Future<void> setColorFilter(String? colorMode) async {
    emit(state.copyWith(selectedColorMode: colorMode, clearColorFilter: colorMode == null));
    await loadVolumes(page: 1, colorMode: colorMode);
  }

  Future<void> setUncensoredFilter(bool? uncensored) async {
    emit(state.copyWith(filterUncensored: uncensored, clearUncensoredFilter: uncensored == null));
    await loadVolumes(page: 1, uncensored: uncensored);
  }

  Future<void> openVolumeDetail(String bookHash) async {
    emit(state.copyWith(loading: true, clearError: true, clearAiSuggestion: true));
    try {
      final vol = await _repo.getVolumeDetail(bookHash);
      emit(state.copyWith(loading: false, activeVolume: vol));
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: 'Error al abrir detalle: $e'));
    }
  }

  void closeVolumeDetail() {
    emit(state.copyWith(clearActiveVolume: true, clearAiSuggestion: true));
  }

  Future<void> requestAiSuggestion(String title) async {
    emit(state.copyWith(aiLoading: true, clearError: true));
    try {
      final suggestion = await _repo.aiSuggestMetadata(title);
      emit(state.copyWith(
        aiLoading: false,
        latestAiSuggestion: suggestion,
        successMessage: suggestion != null ? 'Sugerencias de IA listas' : null,
      ));
    } catch (e) {
      emit(state.copyWith(aiLoading: false, errorMessage: 'Error al invocar IA: $e'));
    }
  }

  Future<bool> saveVolume(String bookHash, Map<String, dynamic> payload) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repo.updateVolume(bookHash, payload);
      emit(state.copyWith(
        saving: false,
        successMessage: 'Metadatos guardados correctamente',
      ));
      // Refresh active volume and list
      await openVolumeDetail(bookHash);
      await loadVolumes(page: state.currentPage);
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, errorMessage: 'Error al guardar metadatos: $e'));
      return false;
    }
  }

  Future<void> syncVolumeFromDisk(String bookHash) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final res = await _repo.syncVolumeFile(bookHash);
      emit(state.copyWith(
        saving: false,
        successMessage: 'Archivo sincronizado con disco: ${res['message'] ?? 'OK'}',
      ));
      await openVolumeDetail(bookHash);
      await loadVolumes(page: state.currentPage);
    } catch (e) {
      emit(state.copyWith(saving: false, errorMessage: 'Error sincronizando archivo: $e'));
    }
  }

  Future<bool> publishVolumeNow(String bookHash, {String? customCaption, bool sendAsFile = true}) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final res = await _repo.publishNow(bookHash: bookHash, customCaption: customCaption, sendAsFile: sendAsFile);
      emit(state.copyWith(
        saving: false,
        successMessage: '¡Publicación enviada a Telegram! (${res['status'] ?? 'OK'})',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, errorMessage: 'Error al publicar en Telegram: $e'));
      return false;
    }
  }

  Future<bool> scheduleVolumePublication(String bookHash, DateTime scheduledDate, {String? customCaption}) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final isoString = scheduledDate.toUtc().toIso8601String();
      final res = await _repo.schedulePublication(bookHash: bookHash, scheduledAtIso: isoString, customCaption: customCaption);
      emit(state.copyWith(
        saving: false,
        successMessage: 'Publicación programada para ${scheduledDate.toLocal()} (${res['status'] ?? 'OK'})',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, errorMessage: 'Error programando publicación: $e'));
      return false;
    }
  }

  Future<void> loadSeries({int page = 1, String? query}) async {
    try {
      final res = await _repo.getSeriesList(page: page, pageSize: 50, query: query);
      emit(state.copyWith(seriesList: res.items, totalSeries: res.total));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error cargando series: $e'));
    }
  }

  Future<bool> saveSeries(String seriesId, Map<String, dynamic> payload) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repo.updateSeries(seriesId, payload);
      emit(state.copyWith(saving: false, successMessage: 'Serie actualizada correctamente'));
      await loadSeries();
      return true;
    } catch (e) {
      emit(state.copyWith(saving: false, errorMessage: 'Error al actualizar serie: $e'));
      return false;
    }
  }

  void clearNotifications() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
