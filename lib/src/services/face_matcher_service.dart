import '../utils/vector_utils.dart';
import '../models/match_result.dart';

class FaceMatcherService {
  /// Compare two face embeddings from MobileFaceNet.
  ///
  /// MobileFaceNet produces L2-normalized 192-d vectors.
  /// Cosine similarity thresholds for MobileFaceNet:
  ///   - Same person: typically 0.5–0.9+
  ///   - Different person: typically 0.0–0.4
  ///   - Match threshold: ~0.55
  MatchResult compareFaces(
    List<double> storedEmbedding,
    List<double> newEmbedding,
  ) {
    if (storedEmbedding.isEmpty || newEmbedding.isEmpty) {
      return MatchResult.fromSimilarity(0.0);
    }

    // Ensure same length
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

    // Note: embeddings are already L2-normalized by FaceEmbeddingService
    final cosineSim = VectorUtils.cosineSimilarity(a, b);

    // Direct mapping: cosine ranges from -1 to 1 for normalized vectors.
    // For MobileFaceNet, same-person similarity is typically 0.5-0.9+
    // and different-person similarity is typically 0.0-0.4.
    // Map to a percentage that makes intuitive sense:
    //   cosineSim 1.0  → 100%
    //   cosineSim 0.55 → 75%  (match threshold)
    //   cosineSim 0.0  → 30%
    //   cosineSim -1.0 → 0%
    double percent;
    if (cosineSim >= 0.55) {
      // Match range: 75% to 100%
      // Map 0.55–1.0 → 75–100
      percent = 75.0 + (cosineSim - 0.55) / (1.0 - 0.55) * 25.0;
    } else if (cosineSim >= 0.0) {
      // No match but positive similarity: 30% to 75%
      // Map 0.0–0.55 → 30–75
      percent = 30.0 + (cosineSim / 0.55) * 45.0;
    } else {
      // Negative similarity: 0% to 30%
      percent = 30.0 + cosineSim * 30.0;
    }

    return MatchResult.fromSimilarity(percent.clamp(0.0, 100.0));
  }
}
