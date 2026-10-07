import 'package:shared_preferences/shared_preferences.dart';

import '/features/zeepub_editorial/data/datasources/zeepub_api_client.dart';
import '/features/zeepub_editorial/data/models/zeepub_ai_suggestion.dart';
import '/features/zeepub_editorial/data/models/zeepub_series.dart';
import '/features/zeepub_editorial/data/models/zeepub_volume.dart';
import '/features/zeepub_editorial/data/models/zeepub_workgroup.dart';

abstract interface class ZeepubEditorialRepository {
  String getBaseUrl();
  Future<void> saveBaseUrl(String url);

  Future<({List<ZeepubVolume> items, int total, int page, int totalPages})> getVolumes({
    int page = 1,
    int pageSize = 30,
    String? query,
    String? seriesId,
    int? workgroupId,
    String? colorMode,
    bool? isUncensored,
  });

  Future<ZeepubVolume> getVolumeDetail(String bookHash);
  Future<void> updateVolume(String bookHash, Map<String, dynamic> payload);
  Future<Map<String, dynamic>> syncVolumeFile(String bookHash);

  Future<({List<ZeepubSeries> items, int total, int page})> getSeriesList({
    int page = 1,
    int pageSize = 50,
    String? query,
  });

  Future<Map<String, dynamic>> getSeriesDetail(String seriesId);
  Future<void> updateSeries(String seriesId, Map<String, dynamic> payload);

  Future<List<ZeepubWorkgroup>> getWorkgroups();
  Future<ZeepubAiSuggestion?> aiSuggestMetadata(String title);

  Future<Map<String, dynamic>> publishNow({
    required String bookHash,
    String? customCaption,
    bool sendAsFile = true,
  });

  Future<Map<String, dynamic>> schedulePublication({
    required String bookHash,
    required String scheduledAtIso,
    String? customCaption,
  });
}

class ZeepubEditorialRepositoryImpl implements ZeepubEditorialRepository {
  final ZeepubApiClient _client;
  final SharedPreferences _prefs;

  static const _urlKey = 'zeepub_api_base_url';

  ZeepubEditorialRepositoryImpl(this._client, this._prefs) {
    final savedUrl = _prefs.getString(_urlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _client.setBaseUrl(savedUrl);
    }
  }

  @override
  String getBaseUrl() => _client.baseUrl;

  @override
  Future<void> saveBaseUrl(String url) async {
    _client.setBaseUrl(url);
    await _prefs.setString(_urlKey, url.trim());
  }

  @override
  Future<({List<ZeepubVolume> items, int total, int page, int totalPages})> getVolumes({
    int page = 1,
    int pageSize = 30,
    String? query,
    String? seriesId,
    int? workgroupId,
    String? colorMode,
    bool? isUncensored,
  }) =>
      _client.getVolumes(
        page: page,
        pageSize: pageSize,
        query: query,
        seriesId: seriesId,
        workgroupId: workgroupId,
        colorMode: colorMode,
        isUncensored: isUncensored,
      );

  @override
  Future<ZeepubVolume> getVolumeDetail(String bookHash) => _client.getVolumeDetail(bookHash);

  @override
  Future<void> updateVolume(String bookHash, Map<String, dynamic> payload) => _client.updateVolume(bookHash, payload);

  @override
  Future<Map<String, dynamic>> syncVolumeFile(String bookHash) => _client.syncVolumeFile(bookHash);

  @override
  Future<({List<ZeepubSeries> items, int total, int page})> getSeriesList({
    int page = 1,
    int pageSize = 50,
    String? query,
  }) =>
      _client.getSeriesList(page: page, pageSize: pageSize, query: query);

  @override
  Future<Map<String, dynamic>> getSeriesDetail(String seriesId) => _client.getSeriesDetail(seriesId);

  @override
  Future<void> updateSeries(String seriesId, Map<String, dynamic> payload) => _client.updateSeries(seriesId, payload);

  @override
  Future<List<ZeepubWorkgroup>> getWorkgroups() => _client.getWorkgroups();

  @override
  Future<ZeepubAiSuggestion?> aiSuggestMetadata(String title) => _client.aiSuggestMetadata(title);

  @override
  Future<Map<String, dynamic>> publishNow({
    required String bookHash,
    String? customCaption,
    bool sendAsFile = true,
  }) =>
      _client.publishNow(bookHash: bookHash, customCaption: customCaption, sendAsFile: sendAsFile);

  @override
  Future<Map<String, dynamic>> schedulePublication({
    required String bookHash,
    required String scheduledAtIso,
    String? customCaption,
  }) =>
      _client.schedulePublication(bookHash: bookHash, scheduledAtIso: scheduledAtIso, customCaption: customCaption);
}
