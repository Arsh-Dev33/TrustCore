import 'dart:math';

class VectorUtils {
  static double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Vectors must be same length');
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  static List<double> normalize(List<double> v) {
    double norm = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    if (norm == 0.0) return v;
    return v.map((x) => x / norm).toList();
  }

  static double similarityToPercent(double similarity) {
    return ((similarity + 1.0) / 2.0 * 100.0).clamp(0.0, 100.0);
  }

  static double euclideanDistance(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return sqrt(sum);
  }
}
