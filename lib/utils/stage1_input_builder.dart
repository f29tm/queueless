import '../services/triage_service.dart';

/// Builds the chief-complaint string exactly as the typed flow always has:
/// selected symptoms joined, then the free-text appended as "Patient says: …".
String buildChiefComplaint({
  required List<String> selectedSymptoms,
  required String complaintText,
}) {
  String chiefComplaint = selectedSymptoms.join(', ');
  final text = complaintText.trim();

  if (text.isNotEmpty) {
    chiefComplaint += chiefComplaint.isNotEmpty
        ? '. Patient says: $text'
        : text;
  }

  if (chiefComplaint.isEmpty) {
    chiefComplaint = 'general complaint';
  }

  return chiefComplaint;
}

/// Single construction path for the Stage 1 payload. Typed and voice/NLP
/// entry both funnel through here, so the request is identical regardless of
/// how the form was filled — extraction adds no triage signal (ML-NLP-01).
Stage1Request buildStage1Request({
  required List<String> selectedSymptoms,
  required String complaintText,
  required int age,
  required int sex,
  required double nrsPain,
  required int mental,
  required int arrivalMode,
  required int injury,
}) {
  return Stage1Request(
    chiefComplaint: buildChiefComplaint(
      selectedSymptoms: selectedSymptoms,
      complaintText: complaintText,
    ),
    age: age,
    sex: sex,
    pain: nrsPain > 0 ? 1 : 2,
    nrsPain: nrsPain,
    mental: mental,
    arrivalMode: arrivalMode,
    injury: injury,
    patientsPerHour: 8,
  );
}
