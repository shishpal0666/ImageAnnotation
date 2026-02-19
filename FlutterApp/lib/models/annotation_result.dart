class AnnotationResult {
  final String description;
  final double distance;

  AnnotationResult({required this.description, required this.distance});

  // Factory constructor to parse the JSON from Node.js
  factory AnnotationResult.fromJson(Map<String, dynamic> json) {
    return AnnotationResult(
      description: json['description'] ?? 'No description',
      // We check for 'score' (which we set in Node) or 'distance'
      distance: (json['score'] ?? json['distance'] ?? 0.0).toDouble(),
    );
  }
}
