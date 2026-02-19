class LocalAnnotation {
  int id; // The visual number (1, 2, 3...)
  double x;
  double y;
  String description;

  LocalAnnotation({
    required this.id,
    required this.x,
    required this.y,
    required this.description,
  });

  // Convert to JSON so we can send it in the HTTP request
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'description': description,
  };
}
