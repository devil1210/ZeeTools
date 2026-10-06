import 'package:freezed_annotation/freezed_annotation.dart';

import 'marc_relator.dart';
import 'subjects.dart';

part 'book_metadata.freezed.dart';
part 'book_metadata.g.dart';

// Texto en otro idioma o escritura (alternate-script). [lang] es una etiqueta
// BCP 47: 'ja' para kanji/kana, 'ja-Latn' para romaji, 'en' para inglés.
@Freezed()
abstract class LocalizedText with _$LocalizedText {
  const factory LocalizedText({
    @Default('') String lang,
    @Default('') String text,
  }) = _LocalizedText;

  factory LocalizedText.fromJson(Map<String, dynamic> json) => _$LocalizedTextFromJson(json);
}

@Freezed()
abstract class Actor with _$Actor {
  const factory Actor({
    @Default('') String name,
    @Default('') String fileAs,
    @Default([]) List<LocalizedText> altNames,
    @Default([]) List<MarcRelator> roles,
  }) = _Actor;

  factory Actor.fromJson(Map<String, dynamic> json) => _$ActorFromJson(json);
}

extension ActorX on Actor {
  bool get isCreator => roles.any((r) => r.creator);
}

// «Nombre Apellido» → «Apellido, Nombre»; un nombre de una sola palabra queda igual.
String fileAsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return name.trim();
  return '${parts.last}, ${parts.sublist(0, parts.length - 1).join(' ')}';
}

@Freezed()
abstract class WebLink with _$WebLink {
  const factory WebLink({
    @Default('') String label,
    @Default('') String url,
    // Lo que se ve del enlace; vacío = la propia URL.
    @Default('') String text,
  }) = _WebLink;

  factory WebLink.fromJson(Map<String, dynamic> json) => _$WebLinkFromJson(json);
}

@Freezed()
abstract class BookMetadata with _$BookMetadata {
  const factory BookMetadata({
    // UUID sin el prefijo urn:uuid:. Nunca se guarda en los perfiles.
    @Default('') String identifier,
    @Default('es') String language,
    @Default('') String title,
    // El título y la serie principales van en inglés; vacío equivale a [language].
    @Default('en') String titleLang,
    @Default('') String titleSort,
    @Default([]) List<LocalizedText> altTitles,
    @Default('') String date,
    @Default('Novela ligera') String bookType,
    @Default('') String description,
    @Default([]) List<Actor> actors,
    @Default([]) List<String> publishers,
    @Default([]) List<WebLink> links,
    @Default('') String isbn13,
    @Default('') String isbn10,
    @Default('') String asin,
    @Default('') String sourceUrl,
    @Default('') String series,
    @Default('en') String seriesLang,
    @Default([]) List<LocalizedText> altSeries,
    @Default('1') String seriesIndex,
    Demographic? demographic,
    @Default([]) List<String> genres,
    @Default([]) List<String> editions,
    // Escala de calibre: 0–10 (medias estrellas).
    int? rating,
  }) = _BookMetadata;

  factory BookMetadata.fromJson(Map<String, dynamic> json) => _$BookMetadataFromJson(json);

  factory BookMetadata.initial() => const BookMetadata(
    actors: [
      Actor(roles: [MarcRelator.aut]),
      Actor(roles: [MarcRelator.ill]),
      Actor(roles: [MarcRelator.trl]),
      Actor(roles: [MarcRelator.mrk]),
      Actor(name: 'ZeePubs', fileAs: 'ZeePubs', roles: [MarcRelator.dst]),
    ],
    publishers: [''],
  );
}

extension BookMetadataX on BookMetadata {
  // Sin nombre de serie el libro es un volumen único.
  bool get hasSeries => series.trim().isNotEmpty;

  // Orden: grupo de edad, demografía, géneros y edición en el orden del catálogo.
  List<String> get subjects => [
    if (demographic case final d?) ...[d.ageGroup, d.label],
    ...literaryGenres.where(genres.contains),
    ...editionFeatures.where(editions.contains),
  ];
}
