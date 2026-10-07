class ZeepubAiSuggestion {
  final String spanishTitle;
  final String englishTitle;
  final String author;
  final double? volume;
  final String demography;

  const ZeepubAiSuggestion({
    this.spanishTitle = '',
    this.englishTitle = '',
    this.author = '',
    this.volume,
    this.demography = '',
  });

  factory ZeepubAiSuggestion.fromJson(Map<String, dynamic> json) {
    return ZeepubAiSuggestion(
      spanishTitle: (json['spanish_title'] ?? '').toString(),
      englishTitle: (json['english_title'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : null,
      demography: (json['demography'] ?? '').toString(),
    );
  }
}
