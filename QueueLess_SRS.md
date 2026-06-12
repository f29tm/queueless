# Software Requirements Specification
## QueueLess — AI-Assisted Emergency Department Triage and Queue Management

| Field | Value |
|---|---|
| Document | Software Requirements Specification (SRS) |
| Version | 1.0 |
| Date | June 2026 |
| Standard | IEEE Std 830-1998 / ISO/IEC/IEEE 29148:2018 |
| Project | QueueLess — Capstone B |
| Course | SWE 499B, Capstone Project in Software Engineering |
| Institution | Abu Dhabi University |
| Team | Group 20 |
| Supervisor | Dr. Meriem Bettayeb |
| Prepared by | Fatima (Project Lead) · Latifa · Aysha Alsholi · Mohammad |

## Document Control

### Revision History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | May 2026 | Group 20 | Initial requirements draft from project proposal. |
| 0.5 | May 2026 | Group 20 | Functional and non-functional requirements expanded; use cases added. |
| 1.0 | June 2026 | Group 20 | Full SRS reconstructed from the implemented system; data model, ML, security, and traceability completed. |

### Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Project Lead | Fatima |  |  |
| Supervisor | Dr. Meriem Bettayeb |  |  |

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Overall Description](#2-overall-description)
- [3. External Interface Requirements](#3-external-interface-requirements)
- [4. System Features (Functional Requirements)](#4-system-features-functional-requirements)
- [5. Data Requirements](#5-data-requirements)
- [6. Machine-Learning Requirements](#6-machine-learning-requirements)
- [7. Non-Functional Requirements](#7-non-functional-requirements)
- [8. Verification and Traceability](#8-verification-and-traceability)
- [9. Appendices](#9-appendices)

---

# 1. Introduction

## 1.1 Purpose

This Software Requirements Specification (SRS) defines the functional and non-functional requirements of QueueLess, an AI-assisted emergency department (ED) triage and queue-management system. The document is written to the structure of IEEE Std 830-1998 and incorporates verification and traceability guidance from ISO/IEC/IEEE 29148:2018. It is intended to be complete enough that a software engineer could design, build, and verify the system from this document alone, without access to the original source repository.

QueueLess allows a patient to describe their symptoms before or upon arriving at a hospital. A two-stage machine-learning model classifies the patient as Emergency, Urgent, or Non-Urgent and assigns a queue position with an estimated waiting time. A nurse later records vital signs, the model re-runs, and the nurse confirms or overrides the result. Every decision is recorded for audit. The design keeps a human in the loop at the point of clinical risk.

## 1.2 Document Conventions

Requirements are uniquely identified. Functional requirements use the form **FR-\<MODULE\>-\<NN\>**, non-functional requirements use **NFR-\<CATEGORY\>-\<NN\>**, machine-learning requirements use **ML-\<NN\>**, and use cases use **UC-\<NN\>**. The key words “shall”, “should”, and “may” follow RFC 2119 usage: “shall” denotes a mandatory requirement, “should” a recommendation, and “may” an option.

Each requirement carries a priority (High, Medium, Low) and an implementation status as of June 2026: **Implemented** (built and tested), **Partial** (partly built), or **Future** (planned, not yet built). The status column lets this document double as an as-built specification and a forward roadmap.

## 1.3 Intended Audience and Reading Suggestions

This document is written for the QueueLess development team, the project supervisor, examiners, and any engineer who later maintains or extends the system. Developers should read Sections 3 to 6 in full. Reviewers and examiners may begin with Sections 1 and 2 for context, then consult Section 4 (features) and Section 7 (quality attributes). Testers should focus on Section 8 (verification and traceability).

## 1.4 Product Scope

QueueLess is a cross-platform mobile and web application backed by a cloud database and a hosted machine-learning service. The product reduces emergency-department crowding and patient anxiety by enabling remote pre-arrival check-in, AI-based urgency classification, priority-based queueing with estimated waiting time, real-time staff dashboards, nurse review and override, and patient notifications.

In scope for the current release: patient registration and authentication, symptom self-report, Stage 1 AI triage, arrival check-in, queue position and wait estimate, nurse and doctor dashboards, Stage 2 AI triage with vitals, human override with audit logging, in-app notifications, an AI assistant chatbot, and Arabic/English bilingual support with right-to-left layout.

Out of scope for the current release (recorded as Future): push notifications via Firebase Cloud Messaging, GPS geofencing for automatic arrival detection, predictive analytics for peak-hour forecasting, automated care-pathway recommendations, hospital EHR/Malaffi integration, payment processing, and multi-hospital deployment.

## 1.5 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|---|---|
| AVPU | Alert, Verbal, Pain, Unresponsive — a four-point scale of patient consciousness. |
| Chief complaint | The patient’s primary stated reason for the visit. |
| Deferral | Automatic flagging of a low-confidence Stage 1 prediction for mandatory nurse review. |
| ED | Emergency Department. |
| Entropy | Shannon entropy of the class-probability distribution, used as the deferral signal. |
| ESI / KTAS | Emergency Severity Index / Korean Triage and Acuity Scale — standard acuity scales. |
| FastAPI | Python web framework hosting the machine-learning inference service. |
| Firestore | Cloud Firestore, the real-time NoSQL document database used for application data. |
| Human-in-the-loop | Design principle requiring clinician confirmation or override of AI output. |
| LOS | Length of stay. |
| NRS | Numeric Rating Scale (0–10) for pain intensity. |
| RBAC | Role-Based Access Control. |
| RTL | Right-to-left text direction (Arabic). |
| SMOTETomek | A combined over- and under-sampling technique for class imbalance. |
| Triage level | System urgency class: Emergency, Urgent (Moderate), or Non-Urgent (Low). |

## 1.6 References

- IEEE Std 830-1998, IEEE Recommended Practice for Software Requirements Specifications.
- ISO/IEC/IEEE 29148:2018, Systems and software engineering — Life cycle processes — Requirements engineering.
- Emergency Service Triage Application dataset (Korean KTAS), Kaggle. 1,267 records, 24 attributes.
- QueueLess Capstone B project report, Group 20, Abu Dhabi University, SWE 499B.
- Project architecture and operating rules (CLAUDE.md, PROJECT_KNOWLEDGE.md), QueueLess repository.

# 2. Overall Description

## 2.1 Product Perspective

QueueLess is a new, self-contained system rather than a component of a larger product. It follows a thin-client architecture in which a Flutter application communicates directly with two cloud back-ends: Cloud Firestore for real-time application data and authentication state, and a stateless FastAPI inference service for machine-learning predictions. A third external service, Google Gemini, powers the patient chatbot. The application is the orchestration point; there is no separate middle-tier server in the current release.

The major components and their responsibilities are:

| Component | Responsibility |
|---|---|
| Flutter client (iOS / Android / Web) | All user interfaces for patient, nurse, and doctor roles; client-side state via the Provider pattern; orchestration of all reads, writes, and API calls. |
| Firebase Authentication | Identity and sign-in for patients (email/password with verification) and staff accounts. |
| Cloud Firestore | Real-time storage for users, the triage queue, medical records, and notifications; the queue collection is the single source of truth for triage flow. |
| FastAPI inference service (HuggingFace Spaces) | Hosts the two-stage ensemble model; exposes Stage 1 and Stage 2 prediction endpoints and a health check; stateless. |
| Google Gemini API | Generates conversational responses for the in-app patient assistant chatbot. |

## 2.2 Product Functions

At a high level, QueueLess provides the following functions:

- Patient account registration, email verification, and sign-in.
- Symptom self-report (structured fields plus free-text) and Stage 1 AI urgency classification.
- Patient-facing triage result without clinical jargon or internal confidence values.
- Arrival check-in that places the patient in the live priority queue.
- Display of queue position and an estimated waiting time.
- Real-time nurse dashboard showing waiting patients ordered by priority.
- Stage 2 AI re-classification after the nurse records vital signs.
- Nurse confirmation or override of the AI decision, with both predictions logged for audit.
- Real-time doctor worklist of patients cleared by the nurse.
- In-app notifications to patients and broadcast alerts to nurses on patient arrival.
- AI assistant chatbot for patient guidance.
- Arabic/English bilingual interface with right-to-left layout.

## 2.3 User Classes and Characteristics

| User class | Characteristics and privileges |
|---|---|
| Patient | General public; may have limited technical or language proficiency. Registers and authenticates via Firebase Auth. Submits symptoms, checks in on arrival, views own queue position and notifications, and uses the chatbot. Never sees AI confidence, entropy, or the deferral flag. |
| Nurse | Clinical staff. Authenticates through the staff portal. Views the live waiting-patient queue, records vital signs, runs Stage 2 triage, and confirms or overrides the AI result. Sees confidence, the deferral flag, and both predictions. |
| Doctor | Clinical staff. Authenticates through the staff portal. Views the real-time worklist of patients the nurse has finalized, with full clinical detail and the final triage level. |
| Administrator / Staff | Operational staff. Authenticates through the staff portal. Accesses the staff dashboard and patient records. (Analytics and user management are conceptual for the current release.) |

## 2.4 Operating Environment

- Client platforms: Android (Galaxy S10 and later class devices), iOS (iPhone 11 and later class devices), and modern desktop web browsers, all served from a single Flutter codebase.
- Network: the client requires internet connectivity for all core functions; no offline mode is provided.
- Back-end: Cloud Firestore and Firebase Authentication on Google infrastructure; the inference service runs on HuggingFace Spaces and may cold-start after inactivity.
- The inference service cold-start can take up to 90 seconds; the client allows for this with a 90-second request timeout.

## 2.5 Design and Implementation Constraints

- The user interface shall use a teal palette for all patient-facing screens and the corporate blue (#2446B8) for all staff-facing screens.
- Patient-facing text shall not expose clinical or model jargon (for example “entropy”, “KTAS”, or “deferred”).
- The Firestore `queue` collection is the single source of truth for the triage flow; the legacy `triageResults`, `checkIns`, and `symptoms` collections shall not be written by the current application.
- Every `queue` document shall contain the `stage1Inputs` map so that Stage 2 can re-run without re-collecting Stage 1 data.
- Composite indexes required by the queue queries must exist in Firestore before deployment.
- Client-side state management uses the Provider pattern; the visual language follows Material Design.
- The estimated-waiting-time constants are fixed values derived from published KTAS/ESI targets cross-checked against the dataset median length of stay; they are not recomputed at runtime.

## 2.6 User Documentation

The system is intended to be self-explanatory, so end-user documentation is limited to in-app guidance: a chatbot that explains the app journey, clear field labels, and inline error and empty-state messages. A short staff orientation note accompanies the nurse and doctor dashboards.

## 2.7 Assumptions and Dependencies

- It is assumed that patients can read either Arabic or English and can operate a smartphone application.
- It is assumed that staff accounts are provisioned in advance by an administrator; the application does not provide staff self-registration.
- The system depends on the availability of Cloud Firestore, Firebase Authentication, the FastAPI inference service, and the Google Gemini API.
- The AI model is a decision-support aid; the nurse retains clinical authority and accountability for the final triage decision.

# 3. External Interface Requirements

## 3.1 User Interfaces

- The patient interface presents, in sequence: a home hub, a symptom-assessment screen (single scrollable form), a triage-result screen, an arrival check-in screen with a prominent queue number, position and wait estimate, a notifications screen, and a chatbot screen. All patient screens use the teal palette.
- The nurse interface presents a live, priority-ordered list of waiting patients. Each patient card shows triage level, queue position, waiting time, age and sex, arrival mode, chief complaint, pain score, mental status, and AI confidence, plus a deferral flag where applicable. A vitals entry sheet runs Stage 2 and offers confirm/override.
- The doctor interface presents a real-time worklist of patients cleared by the nurse, ordered by priority, with full clinical detail.
- All screens shall present distinct loading, error, and empty states; error messages shall be user-friendly rather than raw exception text.
- The interface shall support Arabic and English, including full right-to-left layout for Arabic.

## 3.2 Hardware Interfaces

QueueLess requires no specialized hardware. It runs on commodity smartphones, tablets, and personal computers. Optional device sensors (GPS) are reserved for the Future geofencing feature and are not required by the current release.

## 3.3 Software Interfaces

### 3.3.1 Machine-Learning Inference API

Base URL: `https://f29tm-queueless-triage-api.hf.space`. The service is stateless and exposes the following HTTP endpoints. The client uses a 90-second timeout to absorb cold starts.

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v1/predict-stage1` | POST | Stage 1 prediction from patient self-report. |
| `/api/v1/predict-stage2` | POST | Stage 2 prediction from self-report plus vitals. |
| `/health` | GET | Liveness probe used to wake and verify the service. |

Stage 1 request fields and their encodings:

| Field | Type / encoding | Notes |
|---|---|---|
| `chief_complaint` | string | Free-text primary complaint. |
| `age` | integer | Years; derived from the patient profile date of birth. |
| `sex` | integer | 1 = Male, 2 = Female. |
| `pain` | integer | 1 = pain present, 2 = none (derived from NRS > 0). |
| `nrs_pain` | float | Numeric Rating Scale, 0–10. |
| `mental` | integer | AVPU: 1 = Alert, 2 = Verbal, 3 = Pain response, 4 = Unresponsive. |
| `arrival_mode` | integer | 1 = Walk, 2 = Ambulance, 3 = Car, 4 = Transit, 5 = Referred. |
| `injury` | integer | 1 = Yes, 2 = No. |
| `patients_per_hour` | integer | Department load proxy (fixed value in the current release). |

Stage 2 request: all Stage 1 fields plus `sbp`, `dbp`, `hr`, `rr`, `bt` (°C), `saturation` (%), and `ktas_rn` (nurse acuity impression, 1–5).

Response body (both stages):

| Field | Type | Meaning |
|---|---|---|
| `prediction` | string | One of Emergency, Urgent, Non-Urgent. |
| `confidence` | float | Probability of the predicted class (0–1). |
| `probabilities` | object | Per-class probability map. |
| `deferred` | boolean | True when entropy exceeds the deferral threshold (Stage 1). |
| `entropy` | float | Shannon entropy of the probability distribution, in bits. |
| `stage1_prediction` | string | Stage 1 result echoed back by Stage 2. |
| `confidence_delta` | float | Change in confidence from Stage 1 to Stage 2 (Stage 2 only). |

### 3.3.2 Cloud Firestore

The client reads and writes Firestore directly. Real-time dashboards subscribe to live snapshot streams. Access is governed by the security rules in Section 7.3. The logical data model is defined in Section 5.

### 3.3.3 Firebase Authentication

Patients authenticate with email and password and must verify their email before access is granted. Staff accounts (nurse, doctor, administrator) authenticate through the staff portal: a staff identifier resolves to an account that is authenticated against Firebase Authentication.

### 3.3.4 Google Gemini API

The chatbot sends the patient message to the Gemini generative model over HTTPS and renders the returned text. The API key is stored in a configuration file that is excluded from version control. Replies are rendered as plain text, with no HTML or web-view surface.

## 3.4 Communications Interfaces

- All client-to-back-end communication uses HTTPS.
- Machine-learning requests and responses use JSON over HTTP POST.
- Firestore uses its real-time SDK protocol for snapshot streaming and document operations.

# 4. System Features (Functional Requirements)

Each subsection describes one feature, its priority and current status, and the functional requirements that define it. Requirement identifiers are stable and are referenced by the traceability matrix in Section 8.

## 4.1 Patient Account Management and Authentication

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | A patient creates an account, verifies their email, and signs in. Registration captures the profile data the triage model needs (name, date of birth, gender). Sensitive identifiers are hashed before storage. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-AUTH-01 | The system shall allow a new patient to register with name, email, password, date of birth (DD/MM/YYYY), gender, and contact details. | High | Implemented |
| FR-AUTH-02 | The system shall require email verification before granting a patient access to triage functions. | High | Implemented |
| FR-AUTH-03 | The system shall authenticate patients via Firebase Authentication using email and password. | High | Implemented |
| FR-AUTH-04 | The system shall authenticate staff (nurse, doctor, administrator) through a separate staff portal that resolves a staff identifier to a Firebase-authenticated account. | High | Implemented |
| FR-AUTH-05 | The system shall hash the national identifier and phone number before writing them to the patient profile. | Medium | Implemented |
| FR-AUTH-06 | The system shall provide a password-reset flow for patient accounts. | Medium | Implemented |
| FR-AUTH-07 | The system shall route an authenticated user to the interface for their role (patient, nurse, doctor, administrator). | High | Implemented |

## 4.2 Symptom Assessment and Stage 1 AI Triage

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | A patient reports symptoms on a single scrollable form: chief complaint and free-text description, pain on a 0–10 scale, age and sex (from profile), arrival mode, injury flag, and AVPU mental status. The system calls the Stage 1 endpoint and writes the result and all inputs to the queue. |

**Stimulus / response:** on form submission, the system derives the model inputs, calls `/api/v1/predict-stage1`, and on success creates a queue document with status `pre_arrival`. On failure it shows a user-friendly fallback message and does not corrupt the queue.

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-TRIAGE-01 | The system shall present a single scrollable symptom-assessment form (not a multi-tab layout). | High | Implemented |
| FR-TRIAGE-02 | The system shall collect chief complaint, free-text description, NRS pain (0–10), arrival mode, injury flag, and AVPU mental status. | High | Implemented |
| FR-TRIAGE-03 | The system shall derive age and sex from the stored patient profile. | High | Implemented |
| FR-TRIAGE-04 | The system shall submit the assembled inputs to the Stage 1 prediction endpoint with a 90-second timeout. | High | Implemented |
| FR-TRIAGE-05 | The system shall persist the Stage 1 prediction, confidence, class probabilities, entropy, deferral flag, and the full stage1Inputs map to the patient’s queue document. | High | Implemented |
| FR-TRIAGE-06 | The system shall map the model class to the internal triage level and priority number (Emergency=EMERGENCY=1, Urgent=MODERATE=2, Non-Urgent=LOW=3). | High | Implemented |
| FR-TRIAGE-07 | The system shall handle inference errors and timeouts gracefully, presenting a clear fallback message without crashing. | High | Implemented |
| FR-TRIAGE-08 | The system shall provide a manual (no-AI) pathway in which a patient proceeds to nurse assessment without a Stage 1 prediction. | Medium | Implemented |

## 4.3 Triage Result Presentation

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The patient is shown a colour-coded urgency result in plain language. Internal model signals are deliberately hidden from the patient. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-RESULT-01 | The system shall display the patient’s urgency level using colour coding (red for Emergency, orange for Urgent, green for Non-Urgent). | High | Implemented |
| FR-RESULT-02 | The system shall NOT display AI confidence, entropy, or the deferral flag to the patient. | High | Implemented |
| FR-RESULT-03 | The system shall present the result in plain language free of clinical or model jargon. | High | Implemented |
| FR-RESULT-04 | The system shall offer the patient a clear next action (for example, an “I have arrived” check-in). | High | Implemented |

## 4.4 Arrival Check-In and Queue Entry

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | On arrival the patient confirms presence, which moves their queue document into the nurse-waiting state and assigns a queue number. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-ARRIVE-01 | The system shall let a patient confirm arrival, transitioning their queue document from pre_arrival to waiting_nurse. | High | Implemented |
| FR-ARRIVE-02 | The system shall assign and store a queue number and arrival timestamp on check-in. | High | Implemented |
| FR-ARRIVE-03 | The system shall make the checked-in patient visible on the nurse dashboard in real time. | High | Implemented |
| FR-ARRIVE-04 | The system shall broadcast an arrival notification to all nurse accounts on check-in. | High | Implemented |
| FR-ARRIVE-05 | The system shall provide a GPS geofencing option to detect arrival automatically. | Low | Future |

## 4.5 Queue Position and Estimated Waiting Time

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | After check-in the patient sees their queue number prominently, their position in the priority lane, and an estimated waiting time computed from the patients ahead and per-level service constants. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-QUEUE-01 | The system shall display the patient’s queue number prominently on the arrival-confirmation screen. | High | Implemented |
| FR-QUEUE-02 | The system shall display the patient’s position within their priority lane. | High | Implemented |
| FR-QUEUE-03 | The system shall display an estimated waiting time derived from a priority-aware accumulative model using fixed per-level service constants (Emergency 12 min, Urgent 20 min, Non-Urgent 25 min) with a displayed range of ±25%. | High | Implemented |
| FR-QUEUE-04 | The system shall present the waiting time as a range and note that it may increase if emergency patients arrive. | Medium | Implemented |
| FR-QUEUE-05 | The system shall localize the queue number, position, and waiting-time text in both Arabic and English. | High | Implemented |

## 4.6 Nurse Triage Dashboard

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The nurse sees a live, priority-ordered list of waiting patients. Each card surfaces the clinical signals a nurse needs to prioritize, including the deferral flag for low-confidence cases. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-NURSE-01 | The system shall present a real-time list of waiting_nurse patients ordered by priority. | High | Implemented |
| FR-NURSE-02 | Each patient card shall display triage level, queue position, and time since arrival. | High | Implemented |
| FR-NURSE-03 | Each patient card shall display age, sex, arrival mode, chief complaint, pain score, and mental status, decoded from the stored inputs. | High | Implemented |
| FR-NURSE-04 | Each patient card shall display the AI confidence and shall flag deferred (low-confidence) cases for review. | High | Implemented |
| FR-NURSE-05 | The dashboard shall degrade gracefully for manual check-ins that have no AI data, showing neutral placeholders. | Medium | Implemented |
| FR-NURSE-06 | The dashboard shall provide an action to open the vitals-entry sheet for a selected patient. | High | Implemented |
| FR-NURSE-07 | The dashboard shall alert the nurse when a new patient arrives. | Medium | Implemented |

## 4.7 Stage 2 AI Triage with Vital Signs

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The nurse records vital signs and an acuity impression; the system re-runs the model with the richer feature set and shows the Stage 2 result and the change from Stage 1. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-STAGE2-01 | The system shall let the nurse record SBP, DBP, heart rate, respiratory rate, body temperature, oxygen saturation, and an acuity impression (KTAS 1–5). | High | Implemented |
| FR-STAGE2-02 | The system shall call the Stage 2 endpoint with the stored Stage 1 inputs plus the new vitals. | High | Implemented |
| FR-STAGE2-03 | The system shall display the Stage 2 prediction, its confidence, and the confidence change relative to Stage 1. | High | Implemented |
| FR-STAGE2-04 | Where the Stage 2 prediction differs from Stage 1, the system shall show both predictions and the confidence delta. | High | Implemented |
| FR-STAGE2-05 | Confidence, entropy, and the deferral flag may be shown to the nurse (these are nurse-only signals). | Medium | Implemented |

## 4.8 Nurse Confirmation and Override (Human-in-the-Loop)

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The nurse confirms or overrides the AI decision. The system records the final decision, whether it was an override, and both AI predictions, then advances the patient to the doctor queue and writes an audit record. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-OVERRIDE-01 | The system shall let the nurse confirm the AI result or override it with a different triage level. | High | Implemented |
| FR-OVERRIDE-02 | The system shall record the final triage level, final priority number, the override flag, and both AI predictions on the queue document. | High | Implemented |
| FR-OVERRIDE-03 | On finalization, the system shall transition the queue document to waiting_doctor and stamp a completion time. | High | Implemented |
| FR-OVERRIDE-04 | On finalization, the system shall write an audit record to the medical-records collection capturing inputs, both predictions, and the nurse decision. | High | Implemented |
| FR-OVERRIDE-05 | On finalization, the system shall notify the patient that triage is complete. | Medium | Implemented |

## 4.9 Doctor Worklist Dashboard

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The doctor sees a real-time worklist of patients the nurse has cleared, ordered by priority, with full clinical detail. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-DOCTOR-01 | The system shall present a real-time list of waiting_doctor patients ordered by priority. | High | Implemented |
| FR-DOCTOR-02 | Each entry shall display the final triage level, vitals, and clinical detail. | High | Implemented |
| FR-DOCTOR-03 | The system shall let the doctor mark a patient as seen / discharged, transitioning the queue document accordingly. | Medium | Implemented |

## 4.10 In-App Notifications

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The system delivers in-app notifications to patients (queue position on check-in, triage completion) and broadcasts arrival alerts to all nurses. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-NOTIFY-01 | The system shall notify a patient of their queue position on check-in. | High | Implemented |
| FR-NOTIFY-02 | The system shall notify a patient when their triage is completed. | Medium | Implemented |
| FR-NOTIFY-03 | The system shall broadcast a patient-arrival notification to all accounts with the nurse role. | High | Implemented |
| FR-NOTIFY-04 | The system shall store notifications per user and present them on a notifications screen. | Medium | Implemented |
| FR-NOTIFY-05 | The system shall deliver push notifications via Firebase Cloud Messaging when the app is closed. | Medium | Future |

## 4.11 AI Assistant Chatbot

| Attribute | Value |
|---|---|
| Priority | Medium |
| Status (June 2026) | Implemented |
| Description | A conversational assistant guides the patient through the app and answers general questions using a generative model. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-CHAT-01 | The system shall provide a patient chatbot that sends user messages to the Gemini model and renders the reply. | Medium | Implemented |
| FR-CHAT-02 | The chatbot shall render replies as plain text with no executable or web-view surface. | Medium | Implemented |
| FR-CHAT-03 | The chatbot shall handle service errors gracefully with a connection-error message. | Medium | Implemented |
| FR-CHAT-04 | The chatbot shall present typing and loading feedback during a request. | Low | Implemented |

## 4.12 Multi-Language and RTL Support

| Attribute | Value |
|---|---|
| Priority | High |
| Status (June 2026) | Implemented |
| Description | The application supports Arabic and English, including right-to-left layout for Arabic, applied across patient-facing screens. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-I18N-01 | The system shall support Arabic and English for patient-facing content. | High | Implemented |
| FR-I18N-02 | The system shall apply right-to-left layout and localized Material widgets when Arabic is selected. | High | Implemented |
| FR-I18N-03 | The system shall localize dynamic patient-facing strings, including the arrival and waiting-time messages. | High | Implemented |

## 4.13 Future Features

| Attribute | Value |
|---|---|
| Priority | Low to Medium |
| Status (June 2026) | Future |
| Description | Capabilities promised in earlier project phases but not part of the current release. They are recorded here so a future team can plan them against the same baseline. |

| ID | Requirement | Priority | Status |
|---|---|---|---|
| FR-FUT-01 | The system should deliver push notifications via Firebase Cloud Messaging. | Medium | Future |
| FR-FUT-02 | The system should use GPS geofencing to detect hospital arrival automatically. | Low | Future |
| FR-FUT-03 | The system should provide predictive analytics for peak-hour and resource forecasting. | Low | Future |
| FR-FUT-04 | The system should generate automated care-pathway recommendations. | Low | Future |
| FR-FUT-05 | The system should integrate with hospital EHR systems (for example Malaffi). | Low | Future |
| FR-FUT-06 | The system should support multi-hospital deployment. | Low | Future |

# 5. Data Requirements

## 5.1 Logical Data Model

Application data is stored in Cloud Firestore as collections of JSON-like documents. The active collections are listed below. Legacy collections from earlier prototypes remain in the database but are not written by the current application.

| Collection | Purpose |
|---|---|
| `users` | One document per account (patient, nurse, doctor, administrator). Holds profile and role. Has a `notifications` subcollection per user. |
| `queue` | Single source of truth for the triage flow. One document per patient visit, evolving through the state machine. |
| `medical_records` | Audit trail written when a nurse finalizes a patient; immutable clinical record of the decision. |
| `appointments` / `consultations` / `prescriptions` | Supporting clinical records for the doctor workflow. |
| `triageResults` / `checkIns` / `symptoms` (legacy) | Deprecated; not written by the current application. Read access restricted to staff. |

## 5.2 Data Dictionary

### 5.2.1 users/{uid}

| Field | Type | Description |
|---|---|---|
| `name` | string | Full name. |
| `email` | string | Account email (patients). |
| `dob` | string | Date of birth, format DD/MM/YYYY. |
| `gender` | string | “Male” or “Female”; mapped to sex code for the model. |
| `role` | string | patient, nurse, doctor, or staff/admin. |
| `nationalId` / `phone` | string (hashed) | Hashed at registration. |

### 5.2.2 queue/{docId}

The queue document accumulates fields across three stages of the visit:

| Field | Stage | Description |
|---|---|---|
| `patientId`, `patientName` | Stage 1 | Owner reference and display name. |
| `queueType` | Stage 1 | Department / lane identifier. |
| `status` | all | pre_arrival → waiting_nurse → waiting_doctor → discharged. |
| `triageLevel`, `priorityNumber` | Stage 1 | EMERGENCY/MODERATE/LOW and 1/2/3. |
| `symptoms[]`, `description` | Stage 1 | Selected symptoms and free-text. |
| `aiPrediction`, `confidence` | Stage 1 | Stage 1 class and confidence. |
| `probabilities`, `entropy`, `deferred` | Stage 1 | Probability map, entropy, low-confidence flag. |
| `stage1Inputs{}` | Stage 1 | age, sex, nrs_pain, pain, mental, arrival_mode, injury, chief_complaint, patients_per_hour. |
| `createdAt` | Stage 1 | Creation timestamp. |
| `queueNumber`, `arrivedAt` | Arrival | Assigned on check-in. |
| `sbp`, `dbp`, `hr`, `rr`, `bt`, `o2`, `ktasRn` | Stage 2 | Vitals and nurse acuity impression. |
| `stage2AIResult`, `nurseOverride` | Stage 2 | Stage 2 output and whether the nurse overrode it. |
| `finalTriageLevel`, `finalPriorityNumber` | Stage 2 | The confirmed final decision. |
| `triageCompletedAt` | Stage 2 | Finalization timestamp. |

### 5.2.3 medical_records/{docId}

Written on nurse finalization. Captures the patient reference, the Stage 1 and Stage 2 predictions, the recorded vitals, the nurse decision (confirm or override), and timestamps, forming the immutable audit trail.

## 5.3 Queue State Machine

The queue document is the single source of truth and moves through four states. Each transition has a defined producer.

| From → To | Trigger | Producer |
|---|---|---|
| (none) → pre_arrival | Patient submits symptoms (Stage 1). | Patient app |
| pre_arrival → waiting_nurse | Patient confirms arrival. | Patient app (check-in) |
| waiting_nurse → waiting_doctor | Nurse finalizes Stage 2 (confirm or override). | Nurse dashboard |
| waiting_doctor → discharged | Doctor marks patient seen / discharged. | Doctor dashboard |

## 5.4 Data Integrity and Retention

- Every queue document shall retain its `stage1Inputs` map for the lifetime of the visit so Stage 2 can re-run without re-collecting data.
- Medical-records documents shall be treated as immutable audit records once written.
- Required composite indexes (queueType + status + priorityNumber + createdAt; and patientId + status + createdAt) shall exist before deployment.
- Personal identifiers (national ID, phone) shall be stored only in hashed form.

# 6. Machine-Learning Requirements

Because urgency classification is the system’s core, this section specifies the model independently of the application. It follows the AI/ML guidance added to requirements practice by ISO/IEC/IEEE 29148 derivatives: model specification, data management, performance thresholds, guardrails, and human oversight.

## 6.1 Model Overview

The triage engine is a soft-voting ensemble of four gradient-based and tree-based classifiers: Random Forest, XGBoost, LightGBM, and CatBoost. It outputs a three-class urgency label (Emergency, Urgent, Non-Urgent) together with class probabilities, from which confidence and entropy are derived.

## 6.2 Two-Stage Architecture

The model runs in two stages that mirror the clinical workflow. Stage 1 uses only patient-reportable features and is intentionally limited in accuracy. Stage 2 adds nurse-measured vital signs and an acuity impression, producing a substantially more accurate result. The accuracy gap quantifies the clinical value the nurse adds.

| Stage | Features |
|---|---|
| Stage 1 (self-report) | Chief complaint, age, sex, pain (NRS), mental status, arrival mode, injury, load proxy. |
| Stage 2 (with vitals) | Stage 1 features plus SBP, DBP, HR, RR, body temperature, oxygen saturation, and nurse acuity (KTAS 1–5). |

## 6.3 Dataset and Features

- The model is trained on the Korean Triage and Acuity Scale (KTAS) emergency-service dataset: 1,267 records across 24 attributes.
- The original five-level KTAS labels are collapsed to three classes: KTAS 1–2 → Emergency, KTAS 3 → Urgent, KTAS 4–5 → Non-Urgent.
- Class imbalance is addressed with SMOTETomek applied only to the training fold after the train/test split, so no information leaks from the test set into training.

## 6.4 Training and Validation

| Metric | Value |
|---|---|
| Stage 1 accuracy (self-report only) | 75.20% — an intentional ceiling justified by the literature for self-report inputs. |
| Stage 2 accuracy (with vitals) | 92.13% — about a 16.5 percentage-point gain attributable to nurse vitals. |
| Cross-validation (5-fold) mean | 88.64% ± 0.97% (folds: 89.4, 87.0, 88.1, 89.7, 88.9). |
| Calibration (Brier score) | Approximately 0.041, indicating well-calibrated probabilities. |

## 6.5 Confidence and Deferral

Stage 1 predictions whose probability distribution is too uncertain are deferred for mandatory nurse review. Uncertainty is measured by Shannon entropy of the class probabilities.

| Attribute | Value |
|---|---|
| Deferral threshold | Entropy > 0.705 bits flags the case as deferred. |
| Observed deferral rate | 19 of 254 held-out cases (about 7.5%) were deferred. |
| Patient visibility | The deferral flag is never shown to the patient; it appears only on the nurse dashboard. |

## 6.6 Human-in-the-Loop Guardrails

- The model is decision support only. The nurse confirms or overrides every Stage 2 result, and the nurse decision is authoritative.
- Both AI predictions and the nurse decision are logged for every finalized patient.
- Low-confidence Stage 1 cases are automatically escalated to nurse review through the deferral mechanism.

## 6.7 Machine-Learning Requirements

| ID | Requirement | Priority | Status |
|---|---|---|---|
| ML-01 | The model shall output one of three classes (Emergency, Urgent, Non-Urgent) with per-class probabilities. | High | Implemented |
| ML-02 | Stage 1 shall use only patient-reportable features; Stage 2 shall add nurse-measured vitals and acuity. | High | Implemented |
| ML-03 | The model shall compute Shannon entropy and flag Stage 1 predictions above 0.705 bits as deferred. | High | Implemented |
| ML-04 | Re-sampling for class imbalance shall be applied only after the train/test split (no leakage). | High | Implemented |
| ML-05 | Stage 2 accuracy shall materially exceed Stage 1 accuracy, demonstrating the value of nurse vitals. | High | Implemented |
| ML-06 | The inference service shall expose Stage 1, Stage 2, and health endpoints over HTTPS and return JSON. | High | Implemented |
| ML-07 | The service shall tolerate cold starts; the client shall allow up to 90 seconds per request. | High | Implemented |
| ML-08 | The model shall report calibrated probabilities suitable for confidence display to clinicians. | Medium | Implemented |

## 6.8 Ethics and Safety

- The system presents AI output to patients as an urgency estimate, not a diagnosis, and never exposes raw confidence to patients.
- The intentional Stage 1 accuracy ceiling and the deferral mechanism are safety features: uncertain self-report cases are escalated rather than acted on automatically.
- Clinical accountability remains with the nurse and doctor; the model cannot finalize a patient without nurse action.

# 7. Non-Functional Requirements

## 7.1 Performance

The system shall provide fast responses so that triage does not add delay to patient care, and shall support concurrent access by multiple patients and staff without noticeable degradation.

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-PERF-01 | The mobile application shall initialize within 3 seconds on standard devices (iPhone 11 / Galaxy S10 class). | High | Implemented |
| NFR-PERF-02 | Routine Firestore reads and writes (check-in, queue updates) shall complete within about 2 seconds under normal load. | High | Implemented |
| NFR-PERF-03 | An AI triage result shall normally return within 5 seconds of submission once the service is warm; the client shall tolerate up to 90 seconds on a cold start. | High | Implemented |
| NFR-PERF-04 | Real-time dashboards shall update without manual refresh as queue documents change. | High | Implemented |

## 7.2 Availability and Reliability

QueueLess shall support continuous hospital operation with minimal downtime, and shall recover from failures without losing committed data.

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-AVAIL-01 | The system shall target high availability during operational hours, relying on the managed availability of Firestore and Firebase Authentication. | High | Partial |
| NFR-AVAIL-02 | Committed queue and medical-record writes shall be durable; the system shall not lose finalized clinical data on a client or service restart. | High | Implemented |
| NFR-AVAIL-03 | The system shall degrade gracefully when the inference service is unavailable, allowing the manual nurse pathway to continue. | High | Implemented |

## 7.3 Security

The system shall protect patient and hospital data through encrypted transport, authenticated access, and role-based authorization enforced at the database.

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-SEC-01 | All client-to-back-end communication shall use HTTPS/TLS. | High | Implemented |
| NFR-SEC-02 | The system shall enforce Role-Based Access Control through Firestore security rules. | High | Implemented |
| NFR-SEC-03 | A patient shall be able to read and write only their own queue, records, and notifications. | High | Implemented |
| NFR-SEC-04 | Staff (nurse, doctor) shall be able to read and update any patient’s queue and read clinical records, as their role requires. | High | Implemented |
| NFR-SEC-05 | The rules shall permit any authenticated user to read nurse/doctor/staff profile documents only, to support the nurse-broadcast feature, without exposing patient profiles to other patients. | High | Implemented |
| NFR-SEC-06 | Patients shall verify their email before access is granted. | High | Implemented |
| NFR-SEC-07 | Secrets (API keys, service-account credentials) shall be excluded from version control. | High | Implemented |
| NFR-SEC-08 | Sensitive personal identifiers shall be stored only in hashed form. | Medium | Implemented |
| NFR-SEC-09 | Critical clinical actions (finalization, override) shall be recorded in an audit trail. | High | Implemented |

Authorization summary enforced by the security rules:

| Collection | Patient | Staff (nurse/doctor) |
|---|---|---|
| `users` (own) | read / write own | read own |
| `users` (nurse/doctor/staff profiles) | read only | read |
| `queue` | create / read / update own | read / update any |
| `medical_records` | read own | read any / write |
| `prescriptions` | read own | create / read / update |

## 7.4 Privacy and Compliance

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-PRIV-01 | The system shall follow privacy-by-design and collect only the data needed for triage and queueing. | High | Implemented |
| NFR-PRIV-02 | Patient data shall not be shared with third parties without explicit authorization. | High | Implemented |
| NFR-PRIV-03 | The system should support user consent management and data access/deletion requests. | Medium | Future |

## 7.5 Usability and Accessibility

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-USAB-01 | Core patient tasks (check-in, view queue status) shall require minimal interactions and clear labels. | High | Implemented |
| NFR-USAB-02 | The interface shall present a consistent visual language (teal for patients, #2446B8 for staff) and Material Design components. | High | Implemented |
| NFR-USAB-03 | Patient-facing text shall avoid clinical and model jargon. | High | Implemented |
| NFR-USAB-04 | Every screen shall present distinct loading, error, and empty states with user-friendly messages. | High | Implemented |
| NFR-USAB-05 | The interface shall support Arabic and English including right-to-left layout. | High | Implemented |

## 7.6 Scalability

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-SCAL-01 | The architecture shall scale horizontally with the managed database to support growing numbers of patients and staff. | Medium | Partial |
| NFR-SCAL-02 | The design shall allow new departments, users, and services to be added without major redesign. | Medium | Partial |
| NFR-SCAL-03 | Queue queries shall remain efficient under load through the defined composite indexes; historical documents should be archived to bound collection growth. | Medium | Partial |

## 7.7 Maintainability

| ID | Requirement | Priority | Status |
|---|---|---|---|
| NFR-MAINT-01 | The codebase shall separate user interface, services, and data concerns to aid maintenance. | Medium | Implemented |
| NFR-MAINT-02 | The system shall retain an automated test suite covering the ML contract and key regression risks. | Medium | Implemented |
| NFR-MAINT-03 | Configuration that varies by environment (keys, endpoints) shall be isolated from application logic. | Medium | Implemented |

## 7.8 Quality Constraint Models

The two most safety-relevant quality attributes are specified as constraint models, giving each a measurable baseline, an absolute constraint, and a target.

### 7.8.1 Reliability (Availability)

| Attribute | Value |
|---|---|
| Scale | Percentage of time the system is operational per year. |
| Meter | Calculated from server uptime logs. |
| Baseline | 99% (about 3.65 days downtime per year). |
| Constraint | 99.9% — minimum acceptable (about 8.7 hours downtime per year). |
| Target | 99.95% — high-availability goal (about 4.38 hours downtime per year). |

### 7.8.2 AI Triage Processing Time

| Attribute | Value |
|---|---|
| Scale | Time from symptom submission to classification result. |
| Meter | Average response time over 1,000 concurrent requests (warm service). |
| Baseline | 10 seconds (standard processing). |
| Constraint | 5 seconds — maximum to maintain user flow. |
| Target | 2 seconds — optimum for a real-time experience. |

> **Note:** the constraint model targets assume a warm inference service. The 90-second client timeout exists solely to absorb HuggingFace cold starts and is not a performance target.

# 8. Verification and Traceability

## 8.1 Verification Methods

Each requirement is verified by one of four methods, consistent with ISO/IEC/IEEE 29148:

- **Test (T):** automated or manual execution against expected results.
- **Demonstration (D):** observing the running system perform the function.
- **Inspection (I):** examining code, configuration, or the database.
- **Analysis (A):** reasoning over models, metrics, or logs (for example accuracy and calibration figures).

## 8.2 Current Test Assets

The application carries an automated suite of 35 passing tests, including:

- Unit tests for the triage result mapping and the Stage 1/Stage 2 JSON request contract.
- Unit tests for the chatbot service, including success, server-error, and empty-response handling.
- A widget regression test that asserts the patient result screen never renders AI confidence.
- A widget test that asserts the queue number renders on the arrival-confirmation screen.

## 8.3 Requirements Traceability Matrix

The matrix maps representative requirements to their primary verification method and artifact. Functional requirements within a feature share the feature’s verification approach unless noted.

| Requirement | Method | Verification artifact / activity |
|---|---|---|
| FR-AUTH-01..07 | D / T | Registration, verification, sign-in, and role-routing walkthrough. |
| FR-TRIAGE-04..07 | T | Stage 1 contract unit tests; timeout/error handling test. |
| FR-RESULT-02 | T | Widget regression test (no confidence on patient screen). |
| FR-ARRIVE-01..04 | D / I | Check-in demonstration; Firestore state inspection; nurse-broadcast check. |
| FR-QUEUE-01..05 | T / D | Queue-number widget test; wait-time calculation review. |
| FR-NURSE-01..07 | D | Nurse dashboard demonstration with live and manual records. |
| FR-STAGE2-01..05 | T / D | Stage 2 contract test; confidence-delta demonstration. |
| FR-OVERRIDE-01..05 | D / I | Override demonstration; medical-records audit inspection. |
| FR-DOCTOR-01..03 | D | Doctor worklist demonstration. |
| FR-NOTIFY-01..04 | D / I | Notification delivery demonstration; subcollection inspection. |
| FR-CHAT-01..04 | T / D | Chatbot service tests; conversation demonstration. |
| FR-I18N-01..03 | D | Arabic/English and RTL walkthrough. |
| ML-01..08 | A / T | Accuracy, cross-validation, calibration analysis; contract tests. |
| NFR-SEC-01..09 | I / D | Security-rules inspection; cross-account access attempts. |
| NFR-PERF-01..04 | T / A | Load timing and response measurement. |
| NFR-USAB-01..05 | D | Usability and acceptance walkthrough. |

# 9. Appendices

## Appendix A — Use Case Catalog

Primary actors: Patient, Nurse (triage), Doctor, Administrator. The principal use cases are listed below; they are realized by the features in Section 4.

| ID | Use case | Primary actor |
|---|---|---|
| UC-01 | Register and verify account | Patient |
| UC-02 | Sign in / sign out | All |
| UC-03 | Submit symptoms and receive AI urgency (Stage 1) | Patient |
| UC-04 | Check in on arrival | Patient |
| UC-05 | View queue position and estimated wait | Patient |
| UC-06 | Receive notifications | Patient |
| UC-07 | Use the assistant chatbot | Patient |
| UC-08 | View waiting-patient queue | Nurse |
| UC-09 | Record vitals and run Stage 2 | Nurse |
| UC-10 | Confirm or override triage decision | Nurse |
| UC-11 | View doctor worklist | Doctor |
| UC-12 | Mark patient seen / discharged | Doctor |
| UC-13 | Access patient records / staff dashboard | Administrator |

## Appendix B — Analysis Models

### B.1 Queue State Model

`pre_arrival → waiting_nurse → waiting_doctor → discharged`, with the producers defined in Section 5.3. The queue document is the single shared state object across the patient, nurse, and doctor roles.

### B.2 Triage Sequence (narrative)

1. Patient submits symptoms; the client calls Stage 1 and writes a pre_arrival queue document.
2. Patient arrives and checks in; the document moves to waiting_nurse and nurses are alerted.
3. Nurse records vitals; the client calls Stage 2 and shows the result and confidence delta.
4. Nurse confirms or overrides; the document moves to waiting_doctor and an audit record is written.
5. Doctor reviews and discharges; the document moves to discharged.

## Appendix C — Representative API Payloads

**Stage 1 request:**

```json
{
  "chief_complaint": "chest pain radiating to left arm",
  "age": 45, "sex": 1, "pain": 1, "nrs_pain": 8.0,
  "mental": 1, "arrival_mode": 1, "injury": 2, "patients_per_hour": 8
}
```
**Response:**

```json
{
  "prediction": "Emergency",
  "confidence": 0.941,
  "probabilities": { "Emergency": 0.941, "Urgent": 0.056, "Non-Urgent": 0.003 },
  "deferred": false,
  "entropy": 0.23,
  "stage": 1
}
```
Stage 2 adds the recorded vitals (`sbp`, `dbp`, `hr`, `rr`, `bt`, `saturation`) and the nurse acuity impression (`ktas_rn`) to the Stage 1 fields, and the response additionally carries `stage1_prediction` and `confidence_delta`.

## Appendix D — Technology Summary

| Layer | Technology |
|---|---|
| Frontend | Flutter (iOS / Android / Web), Provider state management, Material Design. |
| Authentication | Firebase Authentication (email/password with verification for patients). |
| Database | Cloud Firestore (real-time NoSQL). |
| ML service | FastAPI on HuggingFace Spaces; soft-voting ensemble (Random Forest, XGBoost, LightGBM, CatBoost). |
| Chatbot | Google Gemini generative model via HTTPS. |
| Dataset | Korean KTAS emergency-service dataset (1,267 records, three-class output). |

---

*End of Software Requirements Specification.*
