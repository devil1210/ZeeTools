class ZeepubWorkgroup {
  final int id;
  final String name;
  final String siglas;
  final String url;
  final String description;

  const ZeepubWorkgroup({
    required this.id,
    required this.name,
    this.siglas = '',
    this.url = '',
    this.description = '',
  });

  factory ZeepubWorkgroup.fromJson(Map<String, dynamic> json) {
    return ZeepubWorkgroup(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      siglas: (json['siglas'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }

  String get displayName => siglas.isNotEmpty ? '$name ($siglas)' : name;
}
