import 'package:flutter/material.dart';

/// Single source of truth for triage-level codes and their shared mappings.
///
/// Firestore stores EMERGENCY / MODERATE / LOW (SRS §5.2.2); the ML API
/// speaks Emergency / Urgent / Non-Urgent. Role-specific presentations that
/// differ on purpose — the darker nurse card palette, the staff dashboard's
/// all-caps labels — stay in their screens but build on these constants.
class TriageLevels {
  TriageLevels._();

  static const String emergency = 'EMERGENCY';
  static const String moderate = 'MODERATE';
  static const String low = 'LOW';

  /// API prediction label → Firestore triageLevel code.
  static String fromPrediction(String prediction) {
    switch (prediction) {
      case 'Emergency':
        return emergency;
      case 'Urgent':
        return moderate;
      default:
        return low;
    }
  }

  /// Queue priority number (1 = most urgent). Unknown levels sort last.
  static int priorityOf(String level) {
    switch (level) {
      case emergency:
        return 1;
      case moderate:
        return 2;
      default:
        return 3;
    }
  }

  /// Patient-friendly English label. [fallback] preserves call-site behaviour
  /// for unexpected values; defaults to 'Non-Urgent'.
  static String labelEn(String level, {String? fallback}) {
    switch (level) {
      case emergency:
        return 'Emergency';
      case moderate:
        return 'Urgent';
      case low:
        return 'Non-Urgent';
      default:
        return fallback ?? 'Non-Urgent';
    }
  }

  /// Patient-friendly Arabic label. Accepts both the internal codes and the
  /// friendly English words, since notifications pass the latter.
  static String labelAr(String level) {
    switch (level.toUpperCase()) {
      case emergency:
        return 'طارئ';
      case moderate:
      case 'URGENT':
        return 'عاجل';
      case low:
      case 'NON-URGENT':
        return 'غير عاجل';
      default:
        return level;
    }
  }

  /// Standard urgency colour (patient/doctor palette — red/orange/green).
  static Color color(String level) {
    switch (level) {
      case emergency:
        return Colors.red;
      case moderate:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  /// Firestore fields produced by a final prediction (nurse finalize and the
  /// staff manual pathway both write this shape).
  static Map<String, dynamic> predictionToFirestore(String prediction) {
    final level = fromPrediction(prediction);
    return {'triageLevel': level, 'priorityNumber': priorityOf(level)};
  }
}
