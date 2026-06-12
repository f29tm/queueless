# Session Notes — Voice & NLP Symptom Entry + Chatbot Redesign

| | |
|---|---|
| **Date** | 10 June 2026 |
| **Branch** | `feature/voice-nlp-symptom-entry` (uncommitted working tree) |
| **Spec** | `QueueLess_Voice_NLP_Symptom_Entry_Addendum.md` (+ `QueueLess_SRS.md`), both copied into the repo root this session |
| **Final state** | `flutter analyze` clean (only pre-existing info lints) · **58/58 tests pass** (35 baseline + 23 new) · debug APK builds · Gemini live and verified |

---

## 1. What was built

### A. Voice & NLP-assisted symptom entry (addendum §4.14, all phases)

A patient can now **dictate or type** a free-text symptom description; a Gemini
NLP step extracts structured form fields and shows them as **pending
suggestions** the patient reviews, applies, and edits before the unchanged
Stage 1 triage call runs.

**Safety rules enforced (and proven by tests):**
- The NLP layer fills **form fields only** — the schema physically contains no
  urgency/severity/acuity/triage field (FR-NLP-02, ML-NLP-01).
- Extracted values are **editable suggestions**; nothing is ever auto-submitted
  (FR-NLP-03). Undetermined fields stay blank, never guessed (FR-NLP-04).
- The Stage 1 payload is **byte-identical** for typed vs extracted entry — both
  funnel through one construction path (`buildStage1Request`).
- Voice is never required; typed entry is the fallback when the mic is denied
  or unsupported (FR-VOICE-04/05). Audio is never stored — transcript text only
  (NFR-PRIV-VOICE-01).
- `chief_complaint` sent to the model is canonical **English** even for Arabic
  dictation; the original transcript is preserved for the record (FR-NLP-05).
- Any extraction error/timeout silently falls back to manual entry (FR-NLP-06).

### B. Chatbot redesign ("innovate")

- **Queue-aware context**: reads the patient's active `queue` doc
  (`patientId + status + createdAt` composite index — no new indexes) and
  injects *patient-safe* fields into the system prompt: status, triage level,
  queue number. Never confidence/entropy/deferred (FR-RESULT-02).
- Visit banner with color-coded urgency chip + status + queue number.
- Personalized greeting (first name) and a "I can see your active visit…" note.
- **Voice input** with **Arabic auto-detection**: Arabic script in the draft or
  last message switches the recognizer locale automatically; manual EN/عربية
  override chips with an "(auto)" tag (FR-VOICE-02). Replies follow the
  patient's language via the updated system instruction.
- Typewriter reveal of replies, timestamps, retry-on-error bubble, contextual
  quick-question chips, "not medical advice — call 999" disclaimer strip,
  gradient header with online dot, new-conversation button.
- `ChatbotService` changes are backward-compatible — all 6 existing service
  tests pass untouched.

---

## 2. Files changed

### New
| File | Purpose |
|---|---|
| `lib/services/speech_input_service.dart` | Wraps `speech_to_text` 7.4: init with permission at point of use, partial results, device-aware locale resolution (`ar_AE` → `ar_SA` → any `ar_*`), graceful unavailable/denied handling |
| `lib/services/symptom_extraction_service.dart` | Gemini structured-JSON extraction: addendum §4 system prompt verbatim, `temperature: 0`, `responseMimeType` + `responseSchema` (six fields only), §4 encoding maps (`kArrivalModeCodes`, `kMentalStatusCodes`), `ExtractedSymptoms` model, null on any failure |
| `lib/utils/stage1_input_builder.dart` | Single Stage 1 payload construction path (typed and NLP entry both use it); byte-identical to the old inline logic |
| `test/unit/symptom_extraction_service_test.dart` | Extraction contract: deterministic config, schema = exactly six fields, **no severity/urgency words** in schema or output, fixed-transcript parsing, null-not-guessed, error fallbacks (500 / non-JSON / empty / blank) |
| `test/unit/stage1_input_builder_test.dart` | Chief-complaint legacy-identical formats; typed vs extracted payload identity; exactly nine Stage 1 keys; pain-flag derivation |
| `test/widget/symptom_assessment_voice_nlp_test.dart` | Real-screen tests: suggestion card renders pending + never auto-submits; dismiss changes nothing; form submits with voice unavailable; typed vs extracted payloads byte-identical end-to-end |
| `tool/check_gemini_key.ps1` | One-command verifier for the Gemini key: tests chatbot path + exact extraction request, prints PASS/FAIL + API error + fix instructions; supports classic `AIza` and new `AQ.` key formats |
| `QueueLess_SRS.md`, `QueueLess_Voice_NLP_Symptom_Entry_Addendum.md` | Spec documents copied into the repo |

### Modified
| File | Change |
|---|---|
| `lib/screens/patient/symptom_assessment_screen.dart` | Mic in the description field, live editable transcript, EN/عربية dictation toggle, "Fill form from my description" button, teal suggestion review card (Apply/Dismiss), amber review banner; submit now uses `buildStage1Request`; writes five new `queue` fields: `inputMethod` (`text` \| `voice` \| `voice+edited`), `transcript`, `transcriptLocale`, `nlpExtracted`, `nlpConfirmed`; optional constructor seams for tests (`speechService`, `extractionService`, `predictStage1`, `profileOverride`) |
| `lib/screens/patient/chatbot_screen.dart` | Full redesign (see §1B) |
| `lib/services/chatbot_service.dart` | Optional patient context appended to the system instruction; `updateContext()`, `resetConversation()`; reply-in-patient's-language + never-reveal-internal-signals instructions |
| `pubspec.yaml` | + `speech_to_text: ^7.3.0` (resolved 7.4.0) |
| `android/app/src/main/AndroidManifest.xml` | + `RECORD_AUDIO` permission, + `android.speech.RecognitionService` `<queries>` intent |
| `ios/Runner/Info.plist` | + `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |
| `lib/config/api_keys.dart` (gitignored) | Replaced depleted key with the new working key |

---

## 3. Gemini outage diagnosed & fixed

- On-device extraction showed "We couldn't analyze your description". Replaying
  the app's exact request revealed **HTTP 429 — prepaid credits depleted** on
  the Google project; all six Gemini models returned 429 (project-wide), so no
  code-side fix was possible. The fallback UX behaved exactly per FR-NLP-06.
- Fatima created a new AI Studio key (new `AQ.` format); verified live with
  `tool/check_gemini_key.ps1`: both paths **PASS**, sample extraction returned
  correctly structured JSON with no severity field.
- Note: `api_keys.dart` was never committed — it is gitignored. Migrating to
  `firebase_ai` (key off-client, NFR-SEC-VOICE-01) remains an optional
  follow-up for the security pass.

---

## 4. Verification summary

| Check | Result |
|---|---|
| `flutter analyze` | 0 errors / 0 warnings (25 pre-existing info lints untouched) |
| `flutter test` | **58/58 pass** — 35 baseline preserved + 23 new |
| `flutter build apk --debug` | Succeeds with new plugin + manifest changes |
| `tool/check_gemini_key.ps1` | PASS chatbot · PASS extraction (live API) |
| On-device | Voice dictation + Arabic chip confirmed working (screenshots); chatbot visit banner, context message, dictation auto-tag, error/retry bubble all confirmed |

### Addendum §2.5 traceability
| Requirement | Test |
|---|---|
| FR-NLP-01/02 (schema, no severity) | `symptom_extraction_service_test.dart` |
| FR-NLP-03 (editable, never auto-submitted) | widget test 1 |
| FR-NLP-04 (blank, not guessed) | unit "leaves undetermined fields null" |
| FR-NLP-06 (error fallback) | unit failure group |
| FR-VOICE-04/05 (typed fallback) | widget test 3 |
| ML-NLP-01 (identical payload) | unit + widget payload-identity tests |

---

## 5. Engineering gotchas worth remembering

1. **`speech_to_text_windows` registers as a Dart plugin in `flutter test` on
   Windows** — `initialize()` hangs instead of failing fast. Widget tests must
   inject a fake speech service (see `_UnavailableSpeechService`).
2. **A second `pumpWidget` in one test reuses element state** unless the root
   widget gets a `UniqueKey()` — `late final` fields set in `initState` keep
   their first-run values otherwise.
3. **PowerShell 5.1 + UTF-8 without BOM**: em dashes mojibake into cp1252
   smart quotes that terminate strings — keep `.ps1` files pure ASCII.

(1 and 2 are saved to Claude's project memory.)

---

## 6. How to test manually on a device

1. `flutter run` → Symptom Assessment → tap the mic (grant permission) → speak
   → transcript appears live and stays editable; switch dictation to العربية
   and dictate Arabic.
2. Tap **Fill form from my description** → review the teal suggestion card →
   **Apply** → chips/slider/details update and stay editable → submit → check
   the new fields on the `queue` doc in Firestore.
3. Deny mic permission (or use web) → friendly message; typing still works
   end-to-end.
4. Chatbot: with an active visit, see the banner + personalized note; ask
   "Where am I in the queue?"; type Arabic → Arabic reply; mic auto-picks
   Arabic after Arabic text; airplane-mode a message → error bubble with
   **Try again**.

---

## 7. Open items / decisions for Fatima

- [ ] **Commit** the branch (one commit, or split feature/chatbot) — nothing is
      committed yet; the diff is the working tree.
- [ ] Optional: migrate Gemini to `firebase_ai` so the key moves off-client
      (NFR-SEC-VOICE-01) — fits Aysha's security workstream.
- [ ] Optional: delete the old depleted key in AI Studio.
- [ ] Arabic dictation quality depends on the device's speech engine (the
      addendum's known weak link) — the editable transcript is the mitigation;
      test on the demo device.
