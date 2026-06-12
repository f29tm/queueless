import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/triage_levels.dart';

const String _baseUrl = 'https://f29tm-queueless-triage-api.hf.space';

/// Holds all fields returned by the triage API for both Stage 1 and Stage 2.
class TriageResult {
  final String prediction;
  final double confidence;
  final Map<String, double> probabilities;
  final bool deferred;
  final double entropy;
  final int stage;
  final String? stage1Prediction;
  final double? confidenceDelta;
  final bool isError;
  final String? errorMessage;

  const TriageResult({
    required this.prediction,
    required this.confidence,
    required this.probabilities,
    required this.deferred,
    required this.entropy,
    required this.stage,
    this.stage1Prediction,
    this.confidenceDelta,
    this.isError = false,
    this.errorMessage,
  });

  factory TriageResult.error(String message) => TriageResult(
    prediction: '',
    confidence: 0,
    probabilities: {},
    deferred: false,
    entropy: 0,
    stage: 0,
    isError: true,
    errorMessage: message,
  );

  /// Maps API prediction label to Firestore triageLevel value.
  String get triageLevel => TriageLevels.fromPrediction(prediction);

  /// Maps prediction to queue priority number (1 = highest urgency).
  int get priorityNumber => TriageLevels.priorityOf(triageLevel);

  /// Returns the ML-result fields to merge into a Firestore queue document.
  Map<String, dynamic> toFirestore() => {
    'aiPrediction': prediction,
    'confidence': confidence,
    'probabilities': probabilities,
    'deferred': deferred,
    'entropy': entropy,
    'triageLevel': triageLevel,
    'priorityNumber': priorityNumber,
  };
}

/// Request fields for Stage 1 (symptoms only).
class Stage1Request {
  final String chiefComplaint;
  final int age;
  final int sex;
  final int pain;
  final double nrsPain;
  final int mental;
  final int arrivalMode;
  final int injury;
  final int patientsPerHour;

  const Stage1Request({
    required this.chiefComplaint,
    required this.age,
    required this.sex,
    required this.pain,
    required this.nrsPain,
    required this.mental,
    required this.arrivalMode,
    required this.injury,
    required this.patientsPerHour,
  });

  Map<String, dynamic> toJson() => {
    'chief_complaint': chiefComplaint,
    'age': age,
    'sex': sex,
    'pain': pain,
    'nrs_pain': nrsPain,
    'mental': mental,
    'arrival_mode': arrivalMode,
    'injury': injury,
    'patients_per_hour': patientsPerHour,
  };
}

/// Request fields for Stage 2 (Stage 1 fields + vitals).
class Stage2Request {
  final Stage1Request stage1;
  final double sbp;
  final double dbp;
  final double hr;
  final double rr;
  final double bt;
  final double saturation;
  final int ktasRn;

  const Stage2Request({
    required this.stage1,
    required this.sbp,
    required this.dbp,
    required this.hr,
    required this.rr,
    required this.bt,
    required this.saturation,
    required this.ktasRn,
  });

  Map<String, dynamic> toJson() => {
    ...stage1.toJson(),
    'sbp': sbp,
    'dbp': dbp,
    'hr': hr,
    'rr': rr,
    'bt': bt,
    'saturation': saturation,
    'ktas_rn': ktasRn,
  };
}

/// HTTP client for the QueueLess triage ML API.
class TriageService {
  // HuggingFace free tier can cold-start in 30–90 s — use a generous timeout.
  static const Duration _timeout = Duration(seconds: 90);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  /// Calls Stage 1 prediction endpoint (symptoms only).
  static Future<TriageResult> predictStage1(Stage1Request request) async {
    return _post('/api/v1/predict-stage1', request.toJson());
  }

  /// Calls Stage 2 prediction endpoint (symptoms + vitals).
  static Future<TriageResult> predictStage2(Stage2Request request) async {
    return _post('/api/v1/predict-stage2', request.toJson());
  }

  /// Derives integer age from a dob string formatted as "DD/MM/YYYY".
  static int ageFromDob(String dob) {
    final parts = dob.split('/');
    final birth = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    final today = DateTime.now();
    int age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age.clamp(0, 120);
  }

  /// Maps gender string to API sex integer (1 = Male, 2 = Female).
  static int sexFromGender(String gender) =>
      gender.toLowerCase() == 'male' ? 1 : 2;

  static Future<TriageResult> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return TriageResult.error(
          'API error ${response.statusCode}: ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final probs = (json['probabilities'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );

      return TriageResult(
        prediction: json['prediction'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        probabilities: probs,
        deferred: json['deferred'] as bool? ?? false,
        entropy: (json['entropy'] as num? ?? 0).toDouble(),
        stage: json['stage'] as int? ?? 1,
        stage1Prediction: json['stage1_prediction'] as String?,
        confidenceDelta: (json['confidence_delta'] as num?)?.toDouble(),
      );
    } on Exception catch (e) {
      return TriageResult.error(e.toString());
    }
  }
}
