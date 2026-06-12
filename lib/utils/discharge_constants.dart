// Constants for the "Left Without Being Seen" (LWBS) discharge action.
//
// LWBS is the standard ED disposition for a patient who departs before triage
// or treatment is complete. Centralised here so the queue write, the audit
// record, and any future reporting all agree on the exact wording.

/// Queue `status` written when a patient is discharged as LWBS.
String dischargeStatus() => 'left_without_being_seen';

/// Human-readable reason stored on the queue doc and the audit record.
String dischargeReason() => 'Patient left without being seen';
