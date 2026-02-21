class FaceRecord {
  final int? id;
  final String userId;
  final String imagePath;
  final List<double> embedding;
  final DateTime registeredAt;

  FaceRecord({
    this.id,
    required this.userId,
    required this.imagePath,
    required this.embedding,
    required this.registeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'image_path': imagePath,
      'embedding': embedding.join(','),
      'registered_at': registeredAt.toIso8601String(),
    };
  }

  factory FaceRecord.fromMap(Map<String, dynamic> map) {
    return FaceRecord(
      id: map['id'],
      userId: map['user_id'],
      imagePath: map['image_path'],
      embedding:
          (map['embedding'] as String).split(',').map(double.parse).toList(),
      registeredAt: DateTime.parse(map['registered_at']),
    );
  }
}
