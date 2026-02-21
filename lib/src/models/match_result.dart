class MatchResult {
  final double similarityPercent;
  final bool isMatch;
  final String verdict;

  MatchResult({
    required this.similarityPercent,
    required this.isMatch,
    required this.verdict,
  });

  static String _getVerdict(double percent) {
    if (percent >= 90) return "Strong Match";
    if (percent >= 80) return "Good Match";
    if (percent >= 70) return "Weak Match";
    return "No Match";
  }

  factory MatchResult.fromSimilarity(double percent) {
    return MatchResult(
      similarityPercent: percent,
      isMatch: percent >= 75.0,
      verdict: _getVerdict(percent),
    );
  }
}
