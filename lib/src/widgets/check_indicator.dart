import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(191), // 0.75 * 255
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: checks.map((check) => _CheckRow(check: check)).toList(),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final CheckItem check;

  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _StatusIcon(status: check.status),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              check.status == CheckStatus.fail && check.failMessage != null
                  ? check.failMessage!
                  : check.label,
              style: TextStyle(
                color: _textColor(check.status),
                fontSize: 13,
                fontWeight: check.status == CheckStatus.fail
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _textColor(CheckStatus status) {
    switch (status) {
      case CheckStatus.pass:
        return Colors.green;
      case CheckStatus.fail:
        return Colors.red;
      case CheckStatus.loading:
        return Colors.yellow;
      case CheckStatus.pending:
        return Colors.white54;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final CheckStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CheckStatus.pass:
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case CheckStatus.fail:
        return const Icon(Icons.cancel, color: Colors.red, size: 18);
      case CheckStatus.loading:
        return const SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.yellow),
        );
      case CheckStatus.pending:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.white38, size: 18);
    }
  }
}
