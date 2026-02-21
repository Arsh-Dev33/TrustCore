import 'package:flutter/material.dart';
import '../../models/face_validation_result.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  final ValidationError error;
  final bool isSuccess;

  const StatusBanner({
    super.key,
    required this.message,
    this.error = ValidationError.none,
    this.isSuccess = false,
  });

  Color get _color {
    if (isSuccess) return Colors.green.shade700;
    if (error == ValidationError.none) return Colors.black87;
    return Colors.red.shade700;
  }

  IconData get _icon {
    if (isSuccess) return Icons.check_circle;
    switch (error) {
      case ValidationError.eyesClosed:
        return Icons.remove_red_eye;
      case ValidationError.noFace:
        return Icons.face;
      case ValidationError.multipleFaces:
        return Icons.group;
      case ValidationError.lookingAway:
        return Icons.rotate_left;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
