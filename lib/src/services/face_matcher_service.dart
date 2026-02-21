import '../utils/vector_utils.dart';
import '../models/match_result.dart';

class FaceMatcherService {
  MatchResult compareFaces(
    List<double> storedEmbedding,
    List<double> newEmbedding,
  ) {
    if (storedEmbedding.isEmpty || newEmbedding.isEmpty) {
      return MatchResult.fromSimilarity(0.0);
    }
    final maxLen = storedEmbedding.length > newEmbedding.length
        ? storedEmbedding.length
        : newEmbedding.length;
    List<double> a = List<double>.from(storedEmbedding);
    List<double> b = List<double>.from(newEmbedding);
    while (a.length < maxLen) {
      a.add(0.0);
    }
    while (b.length < maxLen) {
      b.add(0.0);
    }
    a = VectorUtils.normalize(a);
    b = VectorUtils.normalize(b);
    final cosineSim = VectorUtils.cosineSimilarity(a, b);

    double percent;
    if (cosineSim >= 0.95) {
      percent = 95 + (cosineSim - 0.95) * 100;
    } else if (cosineSim >= 0.85) {
      percent = 80 + (cosineSim - 0.85) * 150;
    } else if (cosineSim >= 0.70) {
      percent = 60 + (cosineSim - 0.70) * 133;
    } else {
      percent = cosineSim * 85;
    }
    return MatchResult.fromSimilarity(percent.clamp(0.0, 100.0));
  }
}
