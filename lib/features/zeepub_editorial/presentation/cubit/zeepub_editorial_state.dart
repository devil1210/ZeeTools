import '../../data/models/zeepub_ai_suggestion.dart';
import '../../data/models/zeepub_series.dart';
import '../../data/models/zeepub_volume.dart';
import '../../data/models/zeepub_workgroup.dart';

class ZeepubEditorialState {
  final bool loading;
  final bool saving;
  final bool aiLoading;
  final String? errorMessage;
  final String? successMessage;

  final List<ZeepubVolume> volumes;
  final int totalVolumes;
  final int currentPage;
  final int totalPages;

  final String searchQuery;
  final String? selectedSeriesId;
  final int? selectedWorkgroupId;
  final String? selectedColorMode;
  final bool? filterUncensored;

  final List<ZeepubSeries> seriesList;
  final int totalSeries;
  final List<ZeepubWorkgroup> workgroups;

  final ZeepubVolume? activeVolume;
  final ZeepubAiSuggestion? latestAiSuggestion;
  final String baseUrl;

  const ZeepubEditorialState({
    this.loading = false,
    this.saving = false,
    this.aiLoading = false,
    this.errorMessage,
    this.successMessage,
    this.volumes = const [],
    this.totalVolumes = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery = '',
    this.selectedSeriesId,
    this.selectedWorkgroupId,
    this.selectedColorMode,
    this.filterUncensored,
    this.seriesList = const [],
    this.totalSeries = 0,
    this.workgroups = const [],
    this.activeVolume,
    this.latestAiSuggestion,
    this.baseUrl = 'http://localhost:8001',
  });

  ZeepubEditorialState copyWith({
    bool? loading,
    bool? saving,
    bool? aiLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    List<ZeepubVolume>? volumes,
    int? totalVolumes,
    int? currentPage,
    int? totalPages,
    String? searchQuery,
    String? selectedSeriesId,
    bool clearSeriesFilter = false,
    int? selectedWorkgroupId,
    bool clearWorkgroupFilter = false,
    String? selectedColorMode,
    bool clearColorFilter = false,
    bool? filterUncensored,
    bool clearUncensoredFilter = false,
    List<ZeepubSeries>? seriesList,
    int? totalSeries,
    List<ZeepubWorkgroup>? workgroups,
    ZeepubVolume? activeVolume,
    bool clearActiveVolume = false,
    ZeepubAiSuggestion? latestAiSuggestion,
    bool clearAiSuggestion = false,
    String? baseUrl,
  }) {
    return ZeepubEditorialState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      aiLoading: aiLoading ?? this.aiLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      volumes: volumes ?? this.volumes,
      totalVolumes: totalVolumes ?? this.totalVolumes,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSeriesId: clearSeriesFilter ? null : (selectedSeriesId ?? this.selectedSeriesId),
      selectedWorkgroupId: clearWorkgroupFilter ? null : (selectedWorkgroupId ?? this.selectedWorkgroupId),
      selectedColorMode: clearColorFilter ? null : (selectedColorMode ?? this.selectedColorMode),
      filterUncensored: clearUncensoredFilter ? null : (filterUncensored ?? this.filterUncensored),
      seriesList: seriesList ?? this.seriesList,
      totalSeries: totalSeries ?? this.totalSeries,
      workgroups: workgroups ?? this.workgroups,
      activeVolume: clearActiveVolume ? null : (activeVolume ?? this.activeVolume),
      latestAiSuggestion: clearAiSuggestion ? null : (latestAiSuggestion ?? this.latestAiSuggestion),
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}
