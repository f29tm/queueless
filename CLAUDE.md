# QueueLess — Claude Code Operating Instructions

> This file is the single source of truth for how Claude Code operates on this project.
> Read it fully before touching any file, every single session.

---

## 0. MANDATORY STARTUP CHECKLIST (Every Session, No Exceptions)

Before doing anything the user asks:

```
1. git log --oneline -15                          # what changed recently
2. git diff HEAD~3 --name-only                    # which files were touched
3. find lib -name "*.dart" | sort                 # current file structure
4. cat pubspec.yaml | grep -A50 "dependencies:"  # dependency state
```

Then cross-check against the task. Only proceed after understanding the current state.

---

## 1. Project Identity

**QueueLess** — AI-powered hospital emergency department triage system.
**University:** Abu Dhabi University | **Course:** SWE 499B | **Group:** 20
**Lead:** Fatima | **Flutter:** Latifa | **Security/Testing:** Aysha | **UML:** Mohammad

---

## 2. Live Infrastructure

| Resource | URL |
|----------|-----|
| Live API root | `https://f29tm-queueless-triage-api.hf.space` |
| Stage 1 | `POST /api/v1/predict-stage1` |
| Stage 2 | `POST /api/v1/predict-stage2` |
| Health check | `GET /health` |
| Backend repo | `https://github.com/f29tm/queueless-backend` |

**HuggingFace cold starts up to 90 seconds. Always use 90s timeout in the service.**

---

## 3. Architecture — LOCKED (Do Not Change Without Fatima Approval)

### Firestore `queue` collection — single source of truth

| Status | Meaning |
|--------|---------|
| `pre_arrival` | Patient submitted symptoms, not yet at hospital |
| `waiting_nurse` | Patient confirmed arrival — appears in nurse dashboard |
| `waiting_doctor` | Nurse finalized — appears in doctor queue |

**Critical rules:**
- Do NOT write triage results to `triageResults` or `checkIns` collections
- Patient screen NEVER shows `deferred` flag — only nurse dashboard reads it
- `queue` documents must always contain `stage1Inputs` (Map) for Stage 2 to use
- `priorityNumber`: Emergency=1, Urgent=2, Non-Urgent=3

### ML Label Mapping

| API returns | Firestore `triageLevel` | `priorityNumber` |
|-------------|------------------------|-----------------|
| "Emergency" | "EMERGENCY" | 1 |
| "Urgent" | "MODERATE" | 2 |
| "Non-Urgent" | "LOW" | 3 |

### Active Branch
**`main` only.** Do not touch latifa-branch — it has merge conflicts and bugs.

---

## 4. API Payloads

### Stage 1 Request
```json
{
  "chief_complaint": "chest pain radiating to left arm",
  "age": 45,
  "sex": 1,
  "pain": 1,
  "nrs_pain": 8.0,
  "mental": 1,
  "arrival_mode": 1,
  "injury": 2,
  "patients_per_hour": 8
}
```

Field codes:
- `sex`: 1=Male, 2=Female
- `pain`: 1=present, 2=none (derive: nrs_pain > 0 → 1)
- `mental`: 1=Alert, 2=Verbal, 3=Pain response, 4=Unresponsive (AVPU)
- `arrival_mode`: 1=Walk, 2=Ambulance, 3=Car, 4=Transit, 5=Referred
- `injury`: 1=Yes, 2=No
- `patients_per_hour`: hardcode 8

### Stage 2 Request
All Stage 1 fields PLUS: `sbp, dbp, hr, rr, bt (°C), saturation (%), ktas_rn (1-5)`

### Response
```json
{
  "prediction": "Emergency",
  "confidence": 0.941,
  "probabilities": {"Emergency": 0.941, "Urgent": 0.056, "Non-Urgent": 0.003},
  "deferred": false,
  "entropy": 0.23,
  "stage": 1
}
```

---

## 5. Patient Profile in Firestore

Collection: `users/{uid}`
- `name` (String)
- `dob` (String — format "DD/MM/YYYY")
- `gender` (String — "Male" or "Female")

Helper functions (already in `lib/services/triage_service.dart`):
- `TriageService.ageFromDob(dob)` — parses DD/MM/YYYY → int age
- `TriageService.sexFromGender(gender)` — "Male"→1, "Female"→2

---

## 6. Feature Status — What's Done vs What's Needed

### ✅ Completed
- Patient symptom assessment (3 tabs: Symptoms, Describe, Details)
- Stage 1 ML API call + Firestore write to `queue`
- Triage result screen (confidence bar, deferred warning, color-coded)
- Arrival check-in (flips `queue` doc to `waiting_nurse`)
- Nurse dashboard (live stream, Stage 2 AI, finalize flow)
- Staff dashboard (live stream from queue)
- `triage_service.dart` (both endpoints, 90s timeout)

### ❌ Still Needed (Build in Priority Order)
1. **Queue number + wait position shown to patient** (after check-in confirmation)
2. **Estimated wait time** (number of patients ahead × avg service time)
3. **Multi-language support** (Arabic + English minimum — promised in Capstone A)
4. **Push notifications** to patient when triage level changes
5. **Firestore security rules** (patients can't read other patients' data)
6. **Chatbot screen** (was in Capstone A prototype)
7. **GPS geofencing** for auto arrival detection (UI shell exists, needs logic)

---

## 7. Design Standards

**Never violate these:**
- Teal (`Colors.teal`) for patient-facing screens
- `#2446B8` blue for nurse/staff screens
- No hardcoded mock data in any screen that will be demoed
- No technical jargon in patient-facing text (no "entropy", no "KTAS", no "deferred")
- Error messages must be user-friendly, not raw exceptions
- Every screen must handle loading state, error state, and empty state
- Reference UX quality bar: Talabat, Seha, Uber apps — not student project aesthetics

---

## 8. Code Rules

- **Show full file before writing** — always, no exceptions
- **Wait for approval before writing** — unless explicitly told to proceed
- **One task at a time** — do not skip ahead
- **Never touch auth flows, login screens, registration** unless explicitly asked
- **Security deferred intentionally** — do not add bcrypt or Firestore rules without being asked (Aysha's tasks)
- **No writes to `triageResults` or `checkIns`** — use `queue` collection only
- **Always check imports** — if you add a new dependency, check pubspec.yaml first

---

## 9. Firestore Composite Indexes (Already Created)

| Collection | Fields |
|------------|--------|
| `queue` | queueType ASC + status ASC + priorityNumber ASC + createdAt ASC |
| `queue` | patientId ASC + status ASC + createdAt DESC |

Do not ask Fatima to create more indexes without verifying these aren't sufficient.

---

## 10. If the API is Down

HuggingFace Spaces sleeps after inactivity. If health check fails:
1. Hit `https://f29tm-queueless-triage-api.hf.space/health` in browser to wake it
2. Wait 60–90 seconds
3. The Flutter timeout is already set to 90s — it will retry naturally
4. Do NOT remove the API call or revert to keyword matching

---

## 11. Report (Fatima's Task — Do Not Touch)

- Due: June 20, 2026
- Format: ADU thesis-style guided template
- Key results: Stage 1 75.98%, Stage 2 92.52%, CV 88.64%±0.97%, Brier 0.041
- Problem: existing draft has wrong authors/supervisor from a template project + intact chapters about an unrelated deaf-blind device — needs full rewrite of several chapters
