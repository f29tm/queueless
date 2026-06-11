# QueueLess — AI-Powered Hospital Triage System

QueueLess is a Flutter mobile app for emergency department triage. Patients submit
symptoms before arriving at hospital. A two-stage AI model classifies urgency;
a nurse adds vitals and the model reruns. Every decision is logged for audit.

## How it works

1. Patient submits chief complaint, pain score, AVPU, and arrival mode via the app.
2. **Stage 1** ML model classifies: Emergency / Urgent / Non-Urgent (75% accuracy —
   intentional ceiling; patient self-report only).
3. Patient arrives, checks in. Queue number + estimated wait displayed immediately.
4. Nurse records BP, HR, RR, O₂, temperature.
5. **Stage 2** model reruns with vitals (92% accuracy). If result changes, nurse sees
   both predictions + confidence delta.
6. Nurse confirms or overrides. Decision logged for audit trail.

## Three roles

| Role | Access | UI colour |
|------|--------|-----------|
| Patient | Symptom assessment, queue position, chatbot | Teal |
| Nurse | Vitals entry, Stage 2 triage, override | #2446B8 |
| Doctor / Staff | Patient queue, records, prescriptions | #2446B8 |

## Tech stack

- **Frontend:** Flutter (iOS / Android / Web) · Firebase Auth · Cloud Firestore · Provider
- **Backend:** FastAPI on HuggingFace Spaces
- **ML:** Ensemble — Random Forest + XGBoost + LightGBM + CatBoost (soft voting)
- **Dataset:** Korean KTAS Emergency Service dataset (1,267 records, 3-class output)
- **Chatbot:** Gemini 2.5 Flash

## Running locally

```bash
flutter pub get
# Add lib/config/api_keys.dart:
# class ApiKeys { static const String gemini = 'YOUR_KEY'; }
flutter run
```

Live ML API: `https://f29tm-queueless-triage-api.hf.space`
Allow up to 90 seconds on first request (HuggingFace cold start).

## Project info

Abu Dhabi University · SWE 499B · Capstone B · Group 20
Supervisor: Dr. Meriem Bettayeb · Submission: June 20, 2026
