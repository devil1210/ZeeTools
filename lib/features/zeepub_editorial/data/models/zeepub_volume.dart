class ZeepubVolume {
  final String id;
  final String bookHash;
  final String title;
  final String spanishTitle;
  final String englishTitle;
  final String? seriesId;
  final String? seriesName;
  final String? seriesSpanish;
  final double? volume;
  final String? edition;
  final String? colorMode;
  final bool isUncensored;
  final String? author;
  final String? illustrator;
  final String? translator;
  final String? layoutBy;
  final String? publisher;
  final String? description;
  final String? coverUrl;
  final String? filepath;
  final String? filename;
  final int? fileSize;
  final String? updatedAt;
  final bool hasBadMetadata;

  const ZeepubVolume({
    required this.id,
    required this.bookHash,
    required this.title,
    this.spanishTitle = '',
    this.englishTitle = '',
    this.seriesId,
    this.seriesName,
    this.seriesSpanish,
    this.volume,
    this.edition,
    this.colorMode,
    this.isUncensored = false,
    this.author,
    this.illustrator,
    this.translator,
    this.layoutBy,
    this.publisher,
    this.description,
    this.coverUrl,
    this.filepath,
    this.filename,
    this.fileSize,
    this.updatedAt,
    this.hasBadMetadata = false,
  });

  factory ZeepubVolume.fromJson(Map<String, dynamic> json) {
    return ZeepubVolume(
      id: (json['id'] ?? json['book_hash'] ?? '').toString(),
      bookHash: (json['book_hash'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      spanishTitle: (json['spanish_title'] ?? '').toString(),
      englishTitle: (json['english_title'] ?? '').toString(),
      seriesId: json['series_id']?.toString(),
      seriesName: json['series_name']?.toString(),
      seriesSpanish: json['series_spanish']?.toString(),
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : null,
      edition: json['edition']?.toString(),
      colorMode: json['color_mode']?.toString(),
      isUncensored: json['is_uncensored'] == true || json['is_uncensored'] == 1,
      author: json['author']?.toString(),
      illustrator: json['illustrator']?.toString(),
      translator: json['translator']?.toString(),
      layoutBy: json['layout_by']?.toString(),
      publisher: json['publisher']?.toString(),
      description: json['description']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      filepath: json['filepath']?.toString(),
      filename: json['filename']?.toString(),
      fileSize: json['file_size'] != null ? (json['file_size'] as num).toInt() : null,
      updatedAt: json['updated_at']?.toString(),
      hasBadMetadata: json['has_bad_metadata'] == true ||
          json['volume'] == null ||
          (json['spanish_title'] ?? '').toString().trim().isEmpty ||
          (json['publisher'] ?? '').toString().trim().isEmpty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'spanish_title': spanishTitle,
      'english_title': englishTitle,
      'volume': volume,
      'edition': edition,
      'color_mode': colorMode,
      'is_uncensored': isUncensored,
      'author': author,
      'illustrator': illustrator,
      'translator': translator,
      'layout_by': layoutBy,
      'publisher': publisher,
      'description': description,
      'cover_url': coverUrl,
    };
  }

  ZeepubVolume copyWith({
    String? id,
    String? bookHash,
    String? title,
    String? spanishTitle,
    String? englishTitle,
    String? seriesId,
    String? seriesName,
    String? seriesSpanish,
    double? volume,
    String? edition,
    String? colorMode,
    bool? isUncensored,
    String? author,
    String? illustrator,
    String? translator,
    String? layoutBy,
    String? publisher,
    String? description,
    String? coverUrl,
    String? filepath,
    String? filename,
    int? fileSize,
    String? updatedAt,
    bool? hasBadMetadata,
  }) {
    return ZeepubVolume(
      id: id ?? this.id,
      bookHash: bookHash ?? this.bookHash,
      title: title ?? this.title,
      spanishTitle: spanishTitle ?? this.spanishTitle,
      englishTitle: englishTitle ?? this.englishTitle,
      seriesId: seriesId ?? this.seriesId,
      seriesName: seriesName ?? this.seriesName,
      seriesSpanish: seriesSpanish ?? this.seriesSpanish,
      volume: volume ?? this.volume,
      edition: edition ?? this.edition,
      colorMode: colorMode ?? this.colorMode,
      isUncensored: isUncensored ?? this.isUncensored,
      author: author ?? this.author,
      illustrator: illustrator ?? this.illustrator,
      translator: translator ?? this.translator,
      layoutBy: layoutBy ?? this.layoutBy,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      filepath: filepath ?? this.filepath,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      updatedAt: updatedAt ?? this.updatedAt,
      hasBadMetadata: hasBadMetadata ?? this.hasBadMetadata,
    );
  }
}
