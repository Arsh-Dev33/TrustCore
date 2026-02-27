import 'package:flutter/material.dart';
import 'dart:ui';

enum CheckStatus { pending, pass, fail, loading }

class CheckItem {
  final String label;
  final CheckStatus status;
  final String? failMessage;

  CheckItem({
    required this.label,
    required this.status,
    this.failMessage,
  });
}

class CheckIndicatorPanel extends StatelessWidget {
  final List<CheckItem> checks;

  const CheckIndicatorPanel({super.key, required this.checks});

  @override
  Widget build(BuildContext context) {
    final passedCount =
        checks.where((c) => c.status == CheckStatus.pass).length;
    final allPassed = passedCount == checks.length;
    final hasFailure = checks.any((c) => c.status == CheckStatus.fail);
    final hasLoading = checks.any((c) => c.status == CheckStatus.loading);

    final failMessage = checks
        .where((c) => c.status == CheckStatus.fail)
        .map((c) => c.failMessage ?? c.label)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withAlpha(28),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dot row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: checks
                    .map((c) => _StatusDot(status: c.status))
                    .toList(),
              ),
              const SizedBox(height: 10),

              // Status label
              if (allPassed)
                const Text(
                  "All checks passed",
                  style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                )
              else if (hasFailure && failMessage != null)
                Text(
                  failMessage,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                )
              else if (hasLoading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Analyzing...",
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  "$passedCount of ${checks.length} verified",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final CheckStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: _dot(),
    );
  }

  Widget _dot() {
    const size = 7.0;
    switch (status) {
      case CheckStatus.pass:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4ADE80),
          ),
        );
      case CheckStatus.fail:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFF6B6B),
          ),
        );
      case CheckStatus.loading:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: const Color(0xFFFBBF24),
          ),
        );
      case CheckStatus.pending:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 1.2),
          ),
        );
    }
  }
}
