class ZeepubSeries {
  final String id;
  final String seriesHash;
  final String name;
  final String seriesSpanish;
  final String seriesEnglish;
  final String slug;
  final String author;
  final String illustrator;
  final String publisher;
  final int bookCount;
  final String coverUrl;
  final String? description;

  const ZeepubSeries({
    required this.id,
    required this.seriesHash,
    required this.name,
    this.seriesSpanish = '',
    this.seriesEnglish = '',
    this.slug = '',
    this.author = '',
    this.illustrator = '',
    this.publisher = '',
    this.bookCount = 0,
    this.coverUrl = '',
    this.description,
  });

  factory ZeepubSeries.fromJson(Map<String, dynamic> json) {
    return ZeepubSeries(
      id: (json['id'] ?? json['series_hash'] ?? '').toString(),
      seriesHash: (json['series_hash'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      seriesSpanish: (json['series_spanish'] ?? '').toString(),
      seriesEnglish: (json['series_english'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      illustrator: (json['illustrator'] ?? '').toString(),
      publisher: (json['publisher'] ?? '').toString(),
      bookCount: json['book_count'] != null ? (json['book_count'] as num).toInt() : 0,
      coverUrl: (json['cover_url'] ?? '').toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'series_spanish': seriesSpanish,
      'series_english': seriesEnglish,
      'author': author,
      'illustrator': illustrator,
      'publisher': publisher,
      'description': description,
    };
  }

  ZeepubSeries copyWith({
    String? id,
    String? seriesHash,
    String? name,
    String? seriesSpanish,
    String? seriesEnglish,
    String? slug,
    String? author,
    String? illustrator,
    String? publisher,
    int? bookCount,
    String? coverUrl,
    String? description,
  }) {
    return ZeepubSeries(
      id: id ?? this.id,
      seriesHash: seriesHash ?? this.seriesHash,
      name: name ?? this.name,
      seriesSpanish: seriesSpanish ?? this.seriesSpanish,
      seriesEnglish: seriesEnglish ?? this.seriesEnglish,
      slug: slug ?? this.slug,
      author: author ?? this.author,
      illustrator: illustrator ?? this.illustrator,
      publisher: publisher ?? this.publisher,
      bookCount: bookCount ?? this.bookCount,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
    );
  }
}
