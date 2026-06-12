import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

/// Structured intake fields extracted from a symptom description.
///
/// Form fields ONLY — by design this never carries urgency, severity, acuity,
/// or a triage level (FR-NLP-02). The Stage 1 model, the entropy deferral, and
/// the nurse remain the only things that set triage (ML-NLP-01).
class ExtractedSymptoms {
  /// Canonical ENGLISH clinical phrase for the model input (FR-NLP-05); the
  /// patient's original-language transcript is kept separately by the caller.
  final String? chiefComplaint;
  final List<String> symptoms;
  final double? nrsPain;
  final bool? injury;
  final String? arrivalMode; // walk | ambulance | car | transit | referred
  final String mentalStatus; // alert | verbal | pain | unresponsive

  const ExtractedSymptoms({
    this.chiefComplaint,
    this.symptoms = const [],
    this.nrsPain,
    this.injury,
    this.arrivalMode,
    this.mentalStatus = 'alert',
  });

  factory ExtractedSymptoms.fromJson(Map<String, dynamic> json) {
    return ExtractedSymptoms(
      chiefComplaint: json['chief_complaint'] as String?,
      symptoms:
          (json['symptoms'] as List?)?.whereType<String>().toList() ?? const [],
      nrsPain: (json['nrs_pain'] as num?)?.toDouble(),
      injury: json['injury'] as bool?,
      arrivalMode: json['arrival_mode'] as String?,
      mentalStatus: (json['mental_status'] as String?) ?? 'alert',
    );
  }

  /// Canonical map persisted to `queue.nlpExtracted` — rebuilt from the typed
  /// fields so only schema-shaped data ever reaches Firestore.
  Map<String, dynamic> toJson() => {
    'chief_complaint': chiefComplaint,
    'symptoms': symptoms,
    'nrs_pain': nrsPain,
    'injury': injury,
    'arrival_mode': arrivalMode,
    'mental_status': mentalStatus,
  };

  /// True when the extractor could not determine anything actionable.
  bool get isEmpty =>
      chiefComplaint == null &&
      symptoms.isEmpty &&
      nrsPain == null &&
      injury == null &&
      arrivalMode == null;
}

/// Field → Stage 1 encoding maps (addendum §4 / SRS §3.3.1). Applied only
/// after the patient confirms the suggestions.
const Map<String, int> kArrivalModeCodes = {
  'walk': 1,
  'ambulance': 2,
  'car': 3,
  'transit': 4,
  'referred': 5,
};

const Map<String, int> kMentalStatusCodes = {
  'alert': 1,
  'verbal': 2,
  'pain': 3,
  'unresponsive': 4,
};

/// Converts a transcript or typed description into [ExtractedSymptoms] via
/// Gemini structured-JSON output (FR-NLP-01). Deterministic (temperature 0).
class SymptomExtractionService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Extraction should feel instant when warm (NFR-PERF-VOICE-01); a hard
  // timeout keeps a slow call from ever blocking manual entry (FR-NLP-06).
  static const Duration _timeout = Duration(seconds: 20);

  // System instruction per addendum §4 — form-filling only, never triage.
  static const String _systemInstruction = '''
You convert a patient's free-text or transcribed symptom description into structured
intake fields for an emergency-department triage FORM. You are a form-filling assistant,
NOT a triage system.

STRICT RULES
- Output ONLY the fields defined by the schema. Never output urgency, severity, acuity,
  a triage level, or medical advice.
- Only fill a field if the patient clearly stated or strongly implied it. If unsure,
  return null for that field. Do not guess.
- chief_complaint: a short, neutral clinical phrase in ENGLISH (e.g. "chest pain radiating
  to left arm"), even if the patient spoke another language. Keep it under ~12 words.
- symptoms: a short list of distinct symptom keywords mentioned.
- nrs_pain: a number 0-10 only if the patient gave or clearly implied a pain level; else null.
- injury: true only if trauma/injury is mentioned; false if explicitly none; else null.
- arrival_mode: one of walk, ambulance, car, transit, referred, only if stated; else null.
- mental_status: default "alert"; use verbal/pain/unresponsive ONLY if the patient or a
  companion clearly describes reduced responsiveness. When in doubt, "alert".
- Do not invent vitals, age, or sex; those come from the profile and the nurse.

Return the patient's words faithfully in chief_complaint meaning, but do not add diagnoses.
''';

  /// Response schema forcing valid JSON in exactly the addendum §5.2 shape —
  /// no urgency or severity field exists for the model to fill (FR-NLP-02).
  static const Map<String, dynamic> responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'chief_complaint': {'type': 'STRING', 'nullable': true},
      'symptoms': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'nrs_pain': {'type': 'NUMBER', 'nullable': true},
      'injury': {'type': 'BOOLEAN', 'nullable': true},
      'arrival_mode': {
        'type': 'STRING',
        'enum': ['walk', 'ambulance', 'car', 'transit', 'referred'],
        'nullable': true,
      },
      'mental_status': {
        'type': 'STRING',
        'enum': ['alert', 'verbal', 'pain', 'unresponsive'],
      },
    },
  };

  final http.Client _client;

  SymptomExtractionService({http.Client? client})
    : _client = client ?? http.Client();

  /// Returns the extracted suggestions, or null on any failure or timeout so
  /// the form silently falls back to manual entry (FR-NLP-06).
  Future<ExtractedSymptoms?> extract(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '$_baseUrl/gemini-2.5-flash:generateContent?key=${ApiKeys.gemini}',
      );

      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': _systemInstruction},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0,
          'responseMimeType': 'application/json',
          'responseSchema': responseSchema,
        },
      });

      final response = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      final parts = (candidates == null || candidates.isEmpty)
          ? null
          : candidates.first['content']?['parts'] as List?;
      final reply = (parts == null || parts.isEmpty)
          ? null
          : parts.first['text'] as String?;

      if (reply == null || reply.isEmpty) return null;

      final decoded = jsonDecode(reply);
      if (decoded is! Map<String, dynamic>) return null;

      return ExtractedSymptoms.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
