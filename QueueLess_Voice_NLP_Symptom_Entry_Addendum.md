# QueueLess — Voice & NLP-Assisted Symptom Entry
## SRS Addendum + Flutter Integration Guide

| Field | Value |
|---|---|
| Document | Addendum to SRS v1.0 (extends §4.2, §5.2, §6, §7, §8) |
| Status | Planned (proposed for next iteration) |
| Date | June 2026 |
| Project | QueueLess — Capstone B, Group 20, Abu Dhabi University |
| Purpose | Let a patient describe symptoms by voice or free text; an NLP layer extracts structured fields and *pre-fills* the symptom form for the patient to confirm before Stage 1 triage runs. |

> **One-line design rule that governs everything below:** the NLP layer fills the form, it does **not** decide urgency. The existing Stage 1 model (FR-TRIAGE-04), the deferral mechanism (ML-03), and the nurse (FR-OVERRIDE) remain the only things that set or change triage. This keeps the feature inside your current human-in-the-loop safety design (§6.6) rather than creating a second, unsanctioned triage path.

---

## 1. Recommended packages (the "ready code" part)

You do not need to build speech recognition or an extraction engine from scratch. Two maintained packages cover both halves.

| Need | Package | Version (Jun 2026) | Platforms | Why this one |
|---|---|---|---|---|
| Voice → text | `speech_to_text` | `^7.3.0` (csdcorp, verified publisher) | Android, iOS, macOS, Web*, Windows (beta) | On-device recognition (no extra service to host), ships a `SpeechToTextProvider` that drops straight into your existing **Provider** state pattern, and selects language per session via `localeId` (incl. Arabic locales installed on the device). |
| Text → structured fields (NLP) | `firebase_ai` | latest | Flutter (Android/iOS/Web/desktop) | Official **successor** to `google_generative_ai`, which Google has **deprecated**. Supports **structured JSON output** via `responseSchema`, and because it runs through Firebase AI Logic it keeps the Gemini key **off the client** — retiring the in-config API key noted in SRS §3.3.4. You already use Firebase, so it slots in. |
| Mic permission (optional helper) | `permission_handler` | latest | Android, iOS | `speech_to_text` can request the mic permission itself on `initialize()`, but `permission_handler` gives you a cleaner "open settings if denied" flow. |

\* `speech_to_text` web support works only in some browsers (Web Speech API). Treat web voice as best-effort; the typed free-text path is the web fallback.

**Two notes before you commit:**
- *Arabic is the weak link, not the packages.* Recognition quality for Gulf/dialectal Arabic depends on the **device's** speech engine, not on `speech_to_text`. Plan to always show the transcript so the patient can correct it, and scope English first (see §6).
- *Lighter alternative for the NLP call:* if you'd rather not add `firebase_ai` yet, you can keep your **current** Gemini HTTP call and just add `responseMimeType: "application/json"` + a schema (or a strict "return only JSON" instruction) and parse the result. Same prompt (§4), fewer moving parts, but the API key stays on the client.

---

## 2. SRS additions

### 2.1 Scope change (§1.4)

Move *voice symptom entry* and *NLP symptom extraction* from implicit/out-of-scope into **in scope (planned)**. No other Future item changes. Payment processing remains out of scope.

### 2.2 New feature — §4.14 Voice & NLP-Assisted Symptom Entry

| Attribute | Value |
|---|---|
| Priority | Medium |
| Status (June 2026) | Planned |
| Description | On the symptom-assessment screen (§4.2), the patient may dictate or type a free-text description. The system transcribes speech to text, sends the text to an NLP extraction service, and uses the result to **pre-fill** the structured fields (chief complaint, symptom list, pain, injury, arrival mode, mental status). The patient reviews and edits every pre-filled field, then submits, after which the existing Stage 1 flow (FR-TRIAGE-04..07) runs unchanged. |

**Voice input requirements**

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-VOICE-01 | The system shall provide a microphone control on the symptom-assessment screen that captures speech and transcribes it to text on-device. | Medium | Planned |
| FR-VOICE-02 | The system shall set the recognition language from the active app locale (English or Arabic) and shall allow the patient to switch it. | Medium | Planned |
| FR-VOICE-03 | The system shall display the live/partial transcript and let the patient edit the final transcript before extraction. | High | Planned |
| FR-VOICE-04 | The system shall request microphone permission at point of use and shall degrade gracefully to typed text if permission is denied or speech recognition is unavailable on the device. | High | Planned |
| FR-VOICE-05 | The system shall not require voice; the typed free-text path (FR-TRIAGE-02) remains fully functional and is the fallback on unsupported browsers/devices. | High | Planned |

**NLP extraction requirements**

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-NLP-01 | The system shall send the transcript or typed description to an NLP extraction service that returns a structured set of candidate form fields as JSON conforming to a fixed schema (§4 of this addendum). | High | Planned |
| FR-NLP-02 | The extraction output shall be limited to factual form fields (chief complaint, symptom list, NRS pain, injury flag, arrival mode, mental status). It shall **not** include any urgency, severity, or triage-level output. | High | Planned |
| FR-NLP-03 | The system shall pre-fill form fields from the extraction result and shall **clearly mark them as suggestions awaiting patient confirmation**; no extracted value shall be submitted without the patient having the opportunity to review and edit it. | High | Planned |
| FR-NLP-04 | Fields the extractor cannot determine shall be left empty for manual entry rather than guessed. | Medium | Planned |
| FR-NLP-05 | The system shall produce a canonical English `chief_complaint` for the model input while preserving the patient's original-language transcript for display and the medical record. *(Assumption: the Stage 1 model's `chief_complaint` feature is English-oriented per the dataset in §6.3. If the model is confirmed language-agnostic, this requirement may be relaxed.)* | Medium | Planned |
| FR-NLP-06 | The system shall handle extraction errors and timeouts gracefully, falling back to the manual form without blocking triage. | High | Planned |

### 2.3 Data model additions (§5.2.2 `queue/{docId}`)

Add to the Stage 1 fields:

| Field | Stage | Description |
|---|---|---|
| `inputMethod` | Stage 1 | `voice`, `text`, or `voice+edited` — how the description was produced. |
| `transcript` | Stage 1 | The raw patient-language transcript/free text as entered (for display and audit). |
| `transcriptLocale` | Stage 1 | Recognition locale used (e.g. `en_US`, `ar_AE`). |
| `nlpExtracted` | Stage 1 | The extraction JSON returned by the NLP service (suggestions). |
| `nlpConfirmed` | Stage 1 | Boolean — patient confirmed/edited the pre-filled fields before submit. |

The existing `chief_complaint` (inside `stage1Inputs`) continues to be the model input; it now receives the canonical English value from FR-NLP-05. `symptoms[]` and `description` are populated as today.

### 2.4 Non-functional & ML notes

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-PERF-VOICE-01 | NLP extraction should return within ~3 s (warm) so it does not slow symptom entry; the screen shall remain usable while extraction runs. | Medium | Planned |
| NFR-PRIV-VOICE-01 | Audio shall be processed for transcription only and shall not be persisted; only the resulting text is stored (`transcript`). | High | Planned |
| NFR-SEC-VOICE-01 | Where `firebase_ai` is used, the model key shall not be embedded in the client (closes the §3.3.4 client-key exposure). | Medium | Planned |
| ML-NLP-01 | The extraction step is assistive only and is excluded from the triage decision path; Stage 1/Stage 2 accuracy figures (§6.4) are unaffected by it. | High | Planned |

### 2.5 Verification & traceability (extend §8.3)

| Requirement | Method | Verification artifact / activity |
|---|---|---|
| FR-VOICE-01..05 | D / T | Dictate a complaint on a device; confirm transcript edit, locale switch, and denied-permission fallback. Widget test: form stays submittable with voice disabled. |
| FR-NLP-01..06 | T / D | Unit test the extraction request/response contract against fixed transcripts; assert output JSON matches schema and contains **no** severity field. Demonstrate pre-fill-and-confirm. |
| FR-NLP-03 | T | Widget test: an extracted value is rendered as an editable suggestion and is never auto-submitted. |
| ML-NLP-01 | A / I | Inspect that the Stage 1 call payload is identical whether fields were typed or extracted (extraction adds no triage signal). |

---

## 3. Flutter setup

### 3.1 `pubspec.yaml`

```yaml
dependencies:
  speech_to_text: ^7.3.0
  firebase_ai: ^2.0.0        # check pub.dev for the current major; API shown in §5
  firebase_core: ^3.0.0      # you already have this
  permission_handler: ^11.0.0  # optional
```

### 3.2 Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Android 11+ needs this so the app can resolve the speech recognition service -->
<queries>
  <intent>
    <action android:name="android.speech.RecognitionService"/>
  </intent>
</queries>
```

Ensure `compileSdkVersion` / `minSdkVersion` meet the plugin's requirements (recent `speech_to_text` needs a modern compile SDK).

### 3.3 iOS — `ios/Runner/Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>QueueLess uses the microphone so you can describe your symptoms by voice.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>QueueLess transcribes your spoken symptoms to help fill in the form.</string>
```

---

## 4. The NLP extraction prompt

Send this as the system instruction; the patient's transcript is the user content. The schema (next section) forces valid JSON, so the model can't ramble.

**System instruction:**

```
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
```

**Field → existing model encoding (your app maps these after the patient confirms):**

| Extracted field | Maps to `stage1Inputs` | Encoding (per SRS §3.3.1) |
|---|---|---|
| `chief_complaint` (English) | `chief_complaint` | string |
| `symptoms[]` | `queue.symptoms[]` / `description` | list / text |
| `nrs_pain` | `nrs_pain` (and derive `pain`) | 0–10; `pain` = 1 if NRS>0 else 2 |
| `injury` (bool) | `injury` | true→1, false→2 |
| `arrival_mode` (enum) | `arrival_mode` | walk1, ambulance2, car3, transit4, referred5 |
| `mental_status` (enum) | `mental` | alert1, verbal2, pain3, unresponsive4 |

---

## 5. Integration code (scaffolding to drop in)

> This is integration scaffolding, not a finished screen — wire it into your existing Provider-based symptom form. Verify constructor/field names against the current `firebase_ai` docs, since that package is evolving.

### 5.1 Voice → text: `SpeechInputService`

```dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechInputService {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  Future<bool> init() async {
    _ready = await _stt.initialize(
      onError: (e) => print('STT error: $e'),
      onStatus: (s) => print('STT status: $s'),
    );
    return _ready;
  }

  bool get isListening => _stt.isListening;

  /// localeId examples: 'en_US', 'ar_AE', 'ar_SA'. Pass the app's active locale.
  Future<void> start({
    required String localeId,
    required void Function(String text, bool isFinal) onText,
  }) async {
    if (!_ready) return;
    await _stt.listen(
      localeId: localeId,
      listenOptions: SpeechListenOptions(partialResults: true),
      onResult: (SpeechRecognitionResult r) =>
          onText(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stop() => _stt.stop();

  /// Optional: confirm the device actually has the requested language.
  Future<bool> supportsLocale(String localeId) async {
    final locales = await _stt.locales();
    return locales.any((l) => l.localeId == localeId);
  }
}
```

### 5.2 Text → fields: `SymptomExtractionService` (firebase_ai, structured output)

```dart
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';

class ExtractedSymptoms {
  final String? chiefComplaint;       // English, for the model
  final List<String> symptoms;
  final double? nrsPain;
  final bool? injury;
  final String? arrivalMode;          // walk|ambulance|car|transit|referred
  final String mentalStatus;          // alert|verbal|pain|unresponsive
  ExtractedSymptoms(this.chiefComplaint, this.symptoms, this.nrsPain,
      this.injury, this.arrivalMode, this.mentalStatus);

  factory ExtractedSymptoms.fromJson(Map<String, dynamic> j) => ExtractedSymptoms(
        j['chief_complaint'] as String?,
        (j['symptoms'] as List?)?.cast<String>() ?? const [],
        (j['nrs_pain'] as num?)?.toDouble(),
        j['injury'] as bool?,
        j['arrival_mode'] as String?,
        (j['mental_status'] as String?) ?? 'alert',
      );
}

class SymptomExtractionService {
  // responseSchema forces valid JSON in the exact shape we want.
  final _schema = Schema.object(properties: {
    'chief_complaint': Schema.string(nullable: true),
    'symptoms': Schema.array(items: Schema.string()),
    'nrs_pain': Schema.number(nullable: true),
    'injury': Schema.boolean(nullable: true),
    'arrival_mode': Schema.enumString(
        enumValues: ['walk', 'ambulance', 'car', 'transit', 'referred'],
        nullable: true),
    'mental_status': Schema.enumString(
        enumValues: ['alert', 'verbal', 'pain', 'unresponsive']),
  });

  static const _systemInstruction = '...'; // the System instruction from §4

  Future<ExtractedSymptoms?> extract(String transcript) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.system(_systemInstruction),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: _schema,
          temperature: 0, // deterministic extraction
        ),
      );
      final res = await model.generateContent([Content.text(transcript)]);
      final text = res.text;
      if (text == null) return null;
      return ExtractedSymptoms.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (e) {
      print('Extraction failed: $e'); // FR-NLP-06: fall back to manual form
      return null;
    }
  }
}
```

### 5.3 Wiring into the form (pre-fill, then **confirm**)

```dart
// In your symptom-form Provider/controller:
Future<void> runVoiceThenExtract(String activeLocale) async {
  final localeId = activeLocale == 'ar' ? 'ar_AE' : 'en_US';

  await _speech.start(
    localeId: localeId,
    onText: (text, isFinal) {
      transcript = text;                 // FR-VOICE-03: show live + let user edit
      notifyListeners();
    },
  );
  // ...user taps "done"; you call _speech.stop() and keep the edited transcript...

  final extracted = await _extractor.extract(transcript);
  if (extracted == null) return;         // manual entry continues

  // Pre-fill as SUGGESTIONS — do not submit. (FR-NLP-03)
  suggestedChiefComplaint = extracted.chiefComplaint;
  suggestedSymptoms       = extracted.symptoms;
  suggestedNrsPain        = extracted.nrsPain;       // null => leave blank (FR-NLP-04)
  suggestedInjury         = extracted.injury;
  suggestedArrivalMode    = extracted.arrivalMode;
  suggestedMental         = extracted.mentalStatus;
  fieldsArePending        = true;        // UI highlights "please confirm"
  notifyListeners();
}

// Only after the patient reviews/edits and taps Submit do you build stage1Inputs
// and call /api/v1/predict-stage1 exactly as today (FR-TRIAGE-04). Nothing about
// the triage call changes — that's the point.
```

---

## 6. Suggested build order

1. **English voice → transcript** with `speech_to_text` on a real device. Get permission + fallback solid first (FR-VOICE-01/04/05).
2. **Extraction in English** with `firebase_ai` structured output; pre-fill + confirm UI (FR-NLP-01/03).
3. **Map confirmed fields** into your existing `stage1Inputs` and run Stage 1 unchanged. Add the unit/widget tests in §2.5.
4. **Add Arabic** (`ar_AE`/`ar_SA` locale + the English `chief_complaint` translation path, FR-NLP-05). Test transcript-edit heavily here — this is where recognition is weakest.
5. **(Optional) Move the Gemini key server-side** by adopting `firebase_ai`'s Firebase AI Logic backend, closing the §3.3.4 client-key note.

## 7. Safety guardrails (keep these explicit in the report)

- The NLP layer outputs **form fields only** — no urgency, no advice (FR-NLP-02). Your urgency story stays exactly as documented: Stage 1 model → entropy deferral → nurse override.
- Every extracted field is an **editable suggestion the patient confirms** (FR-NLP-03), consistent with your "patient confirms, plain language" result design (§4.3) and human-in-the-loop principle (§6.6).
- **Voice is never required** (FR-VOICE-05); typed entry remains the baseline and the web/denied-permission fallback.
- **Audio isn't stored** — only the transcript text (NFR-PRIV-VOICE-01).
