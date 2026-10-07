import 'dart:convert';
import 'dart:io';

import '../models/zeepub_ai_suggestion.dart';
import '../models/zeepub_series.dart';
import '../models/zeepub_volume.dart';
import '../models/zeepub_workgroup.dart';

class ZeepubApiClient {
  String baseUrl;
  final HttpClient _httpClient;

  ZeepubApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? 'http://localhost:8001',
        _httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  void setBaseUrl(String url) {
    if (url.trim().isNotEmpty) {
      baseUrl = url.trim().replaceAll(RegExp(r"/+$"), "");
    }
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw HttpException('Error HTTP ${response.statusCode}: $responseBody', uri: uri);
    }
  }

  Future<dynamic> _getRaw(String path, [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody);
    } else {
      throw HttpException('Error HTTP ${response.statusCode}: $responseBody', uri: uri);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _httpClient.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final jsonString = jsonEncode(body);
    request.write(jsonString);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw HttpException('Error HTTP ${response.statusCode}: $responseBody', uri: uri);
    }
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await _httpClient.putUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final jsonString = jsonEncode(body);
    request.write(jsonString);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      throw HttpException('Error HTTP ${response.statusCode}: $responseBody', uri: uri);
    }
  }

  // --- Volumes ---

  Future<({List<ZeepubVolume> items, int total, int page, int totalPages})> getVolumes({
    int page = 1,
    int pageSize = 30,
    String? query,
    String? seriesId,
    int? workgroupId,
    String? colorMode,
    bool? isUncensored,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();
    if (seriesId != null && seriesId.trim().isNotEmpty) params['series_id'] = seriesId.trim();
    if (workgroupId != null) params['workgroup_id'] = workgroupId.toString();
    if (colorMode != null && colorMode.trim().isNotEmpty) params['color_mode'] = colorMode.trim();
    if (isUncensored != null) params['is_uncensored'] = isUncensored.toString();

    final data = await _get('/api/editorial/volumes', params);
    final rawList = (data['items'] as List<dynamic>?) ?? [];
    final items = rawList.map((e) => ZeepubVolume.fromJson(e as Map<String, dynamic>)).toList();
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;

    return (items: items, total: total, page: page, totalPages: totalPages);
  }

  Future<ZeepubVolume> getVolumeDetail(String bookHash) async {
    final data = await _get('/api/editorial/volume/$bookHash');
    final bookData = data['book'] as Map<String, dynamic>? ?? data;
    return ZeepubVolume.fromJson(bookData);
  }

  Future<void> updateVolume(String bookHash, Map<String, dynamic> payload) async {
    await _put('/api/editorial/volume/$bookHash', payload);
  }

  Future<Map<String, dynamic>> syncVolumeFile(String bookHash) async {
    return await _post('/api/editorial/volume/$bookHash/sync-file', {});
  }

  // --- Series ---

  Future<({List<ZeepubSeries> items, int total, int page})> getSeriesList({
    int page = 1,
    int pageSize = 50,
    String? query,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();

    final data = await _get('/api/editorial/series', params);
    final rawList = (data['items'] as List<dynamic>?) ?? [];
    final items = rawList.map((e) => ZeepubSeries.fromJson(e as Map<String, dynamic>)).toList();
    final total = (data['total'] as num?)?.toInt() ?? items.length;

    return (items: items, total: total, page: page);
  }

  Future<Map<String, dynamic>> getSeriesDetail(String seriesId) async {
    return await _get('/api/editorial/series/$seriesId');
  }

  Future<void> updateSeries(String seriesId, Map<String, dynamic> payload) async {
    await _put('/api/editorial/series/$seriesId', payload);
  }

  // --- Workgroups ---

  Future<List<ZeepubWorkgroup>> getWorkgroups() async {
    final raw = await _getRaw('/api/editorial/groups');
    if (raw is List) {
      return raw.map((e) => ZeepubWorkgroup.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // --- AI Suggest ---

  Future<ZeepubAiSuggestion?> aiSuggestMetadata(String title) async {
    final data = await _post('/api/editorial/ai/suggest', {'title': title});
    if (data['success'] == true && data['metadata'] != null) {
      return ZeepubAiSuggestion.fromJson(data['metadata'] as Map<String, dynamic>);
    }
    return null;
  }

  // --- Telegram Publication ---

  Future<Map<String, dynamic>> publishNow({
    required String bookHash,
    String? customCaption,
    bool sendAsFile = true,
  }) async {
    return await _post('/api/editorial/publish/now', {
      'book_hash': bookHash,
      if (customCaption != null) 'custom_caption': customCaption,
      'send_as_file': sendAsFile,
    });
  }

  Future<Map<String, dynamic>> schedulePublication({
    required String bookHash,
    required String scheduledAtIso,
    String? customCaption,
  }) async {
    return await _post('/api/editorial/publish/schedule', {
      'book_hash': bookHash,
      'scheduled_at': scheduledAtIso,
      if (customCaption != null) 'custom_caption': customCaption,
    });
  }
}
