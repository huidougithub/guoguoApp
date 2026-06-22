class StudyMaterialItem {
  const StudyMaterialItem({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    this.assetPath,
    this.localPath,
    this.pageAssets = const [],
    this.imported = false,
    this.sizeBytes = 0,
  });

  final String id;
  final String title;
  final String description;
  final String fileName;
  final String? assetPath;
  final String? localPath;
  final List<String> pageAssets;
  final bool imported;
  final int sizeBytes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fileName': fileName,
      'assetPath': assetPath,
      'localPath': localPath,
      'pageAssets': pageAssets,
      'imported': imported,
      'sizeBytes': sizeBytes,
    };
  }

  factory StudyMaterialItem.fromJson(Map<String, dynamic> json) {
    return StudyMaterialItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      assetPath: json['assetPath'] as String?,
      localPath: json['localPath'] as String?,
      pageAssets:
          (json['pageAssets'] as List<dynamic>?)
              ?.map((asset) => asset as String)
              .toList() ??
          const [],
      imported: json['imported'] as bool? ?? false,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }
}
