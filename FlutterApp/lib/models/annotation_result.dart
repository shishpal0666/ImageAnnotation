class AnnotationResult {
  final String description;
  final double distance;

  final String? imageUrl; // Relative path from Node.js

  AnnotationResult({
    required this.description, 
    required this.distance,
    this.imageUrl,
  });

  factory AnnotationResult.fromJson(Map<String, dynamic> json) {
    // We only assign imageUrl if the backend actually sent a valid string
    String? parsedUrl = json['imageUrl'];
    if (parsedUrl == 'null' || parsedUrl == null) {
      parsedUrl = null;
    }

    return AnnotationResult(
      description: json['description'] ?? 'No description',
      distance: (json['score'] ?? json['distance'] ?? 0.0).toDouble(),
      imageUrl: parsedUrl,
    );
  }
}
