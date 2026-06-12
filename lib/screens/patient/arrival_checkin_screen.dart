import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/wait_estimator.dart';
import '../../services/notification_service.dart';
import 'appointment_arrival_screen.dart';

/// True once a queue doc has moved past `pre_arrival` — i.e. the patient has
/// already checked in (or been triaged/seen). Used to guard against a second
/// "I have arrived" tap re-flipping an already-active doc. Pure and public so
/// the decision is unit-testable without Firebase.
bool arrivalAlreadyCheckedIn(String? status) =>
    status == 'waiting_nurse' ||
    status == 'waiting_doctor' ||
    status == 'completed';

class ArrivalCheckInScreen extends StatefulWidget {
  final String? queueDocId;

  const ArrivalCheckInScreen({super.key, this.queueDocId});

  @override
  State<ArrivalCheckInScreen> createState() => _ArrivalCheckInScreenState();
}

class _ArrivalCheckInScreenState extends State<ArrivalCheckInScreen> {
  bool _isConfirming = false;
  bool _confirmed = false;
  String? _resolvedDocId;
  String _queueNumber = '-';
  int? _waitPosition;
  String _estimatedWaitText = '-';
  bool _showLowPriorityNote = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ownDocSub;

  // Estimated-wait math lives in the pure, unit-tested WaitEstimator (APQ —
  // accumulative priority queue). See lib/utils/wait_estimator.dart for the
  // service-time constants and their clinical basis.

  @override
  void initState() {
    super.initState();
    _resolvedDocId = widget.queueDocId;
    if (_resolvedDocId == null) {
      _lookupPendingDoc();
    }
  }

  @override
  void dispose() {
    _ownDocSub?.cancel();
    super.dispose();
  }

  /// Live position and wait estimate from the patient's OWN queue doc.
  ///
  /// Security rules block patients from reading anyone else's queue doc, so
  /// this screen cannot compute "N patients ahead" itself. Staff sessions
  /// fan out `currentPosition` onto each doc (see QueuePositionFanout); we
  /// just listen to ours and render whatever lands.
  void _listenToOwnDoc(DocumentReference<Map<String, dynamic>> docRef) {
    _ownDocSub?.cancel();
    _ownDocSub = docRef.snapshots().listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;
      final position = (data['currentPosition'] as num?)?.toInt();
      final estMin = (data['estimatedWaitMinutes'] as num?)?.toInt();
      final level = _normalizeLevel(data['triageLevel']);
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      setState(() {
        _waitPosition = position;
        if (position == null) {
          _estimatedWaitText = '-';
        } else if (estMin != null && estMin > 0) {
          _estimatedWaitText =
              '${WaitEstimator.rangeLow(estMin)}–${WaitEstimator.rangeHigh(estMin)} min';
        } else {
          _estimatedWaitText = WaitEstimator.waitText(
            level,
            position - 1,
            nextLabel: isArabic ? 'الآن' : 'Now',
          );
        }
      });
    });
  }

  Future<void> _lookupPendingDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('queue')
          .where('patientId', isEqualTo: uid)
          .where('status', isEqualTo: 'pre_arrival')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty && mounted) {
        setState(() => _resolvedDocId = query.docs.first.id);
        return;
      }
      // No pending triage — check for an upcoming appointment instead.
      await _checkForAppointment(uid);
    } catch (_) {
      // Best-effort lookup: if it fails, _resolvedDocId stays null and
      // _confirmArrival shows the friendly "no pending triage" prompt.
    }
  }

  /// If the patient has an upcoming scheduled appointment (today or within the
  /// next 24 h), navigate directly to the appointment check-in screen so they
  /// don't land on the "no pending triage" error.
  Future<void> _checkForAppointment(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: uid)
          .where('status', isEqualTo: 'scheduled')
          .get();
      if (snap.docs.isEmpty || !mounted) return;

      // Pick the appointment whose date is today or soonest upcoming.
      // date field is stored as a string like "Mon, Jun 15".
      final now = DateTime.now();
      QueryDocumentSnapshot<Map<String, dynamic>>? best;
      DateTime? bestDt;
      for (final doc in snap.docs) {
        final dt = _parseAppointmentDateTime(
          doc.data()['date'] as String? ?? '',
          doc.data()['time'] as String? ?? '',
        );
        if (dt == null) continue;
        // Accept if within next 8 hours (they're arriving for it now).
        final diff = dt.difference(now);
        if (diff.inHours >= -1 && diff.inHours <= 8) {
          if (bestDt == null || dt.isBefore(bestDt)) {
            best = doc;
            bestDt = dt;
          }
        }
      }

      if (best == null || !mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentArrivalScreen(
            appointmentId: best!.id,
            appointmentData: best.data(),
          ),
        ),
      );
    } catch (_) {
      // If appointment lookup fails, fall through to normal flow.
    }
  }

  /// Parses the stored date/time strings ("Mon, Jun 15" + "09:00 AM") into a
  /// DateTime. Returns null if parsing fails.
  DateTime? _parseAppointmentDateTime(String dateStr, String timeStr) {
    try {
      final datePart = dateStr.contains(',')
          ? dateStr.split(',').last.trim()
          : dateStr.trim();
      final monthDay = datePart.split(' ');
      if (monthDay.length < 2) return null;
      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };
      final month = months[monthDay[0]];
      final day = int.tryParse(monthDay[1]);
      if (month == null || day == null) return null;

      // Parse time like "09:00 AM" / "11:00 PM"
      final timeParts = timeStr.trim().split(' ');
      if (timeParts.length < 2) return null;
      final hmParts = timeParts[0].split(':');
      if (hmParts.length < 2) return null;
      var hour = int.tryParse(hmParts[0]) ?? 0;
      final minute = int.tryParse(hmParts[1]) ?? 0;
      final isPm = timeParts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final now = DateTime.now();
      // Assume current year; roll to next if the month is already past.
      var year = now.year;
      if (month < now.month || (month == now.month && day < now.day)) {
        year++;
      }
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmArrival() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_resolvedDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "لا يوجد طلب فرز أو موعد معلق. أكمل تقييم الأعراض أو احجز موعداً أولاً."
                : "No pending triage or appointment found. Please complete symptom assessment or book an appointment first.",
          ),
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('queue')
          .doc(_resolvedDocId);
      final existingDoc = await docRef.get();
      final existingData = existingDoc.data();

      // Double check-in guard: if this doc is already past pre_arrival, the
      // patient tapped "I have arrived" twice (or returned to this screen).
      // Show their existing place and stop — never re-flip an active doc.
      if (arrivalAlreadyCheckedIn(existingData?['status'] as String?)) {
        if (mounted) {
          setState(() {
            _confirmed = true;
            _isConfirming = false;
            _queueNumber = existingData?['queueNumber'] as String? ?? '-';
            _waitPosition = (existingData?['currentPosition'] as num?)?.toInt();
          });
          _listenToOwnDoc(docRef);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'لقد تم تسجيل وصولك بالفعل. يرجى الجلوس.'
                    : 'You are already checked in. Please take a seat.',
              ),
            ),
          );
        }
        return;
      }

      final queueNumber =
          existingData?['queueNumber'] as String? ??
          'Q${_resolvedDocId!.substring(0, 6).toUpperCase()}';

      await FirebaseFirestore.instance
          .collection('queue')
          .doc(_resolvedDocId)
          .update({
            'queueType': 'nurse',
            'status': 'waiting_nurse',
            'queueNumber': queueNumber,
            'arrivedAt': FieldValue.serverTimestamp(),
          });

      // BEHAVIOUR: this patient is now waiting_nurse. We can NOT compute the
      // queue position here — security rules block patients from reading any
      // queue doc but their own, so a lane-wide query would be denied. The
      // nurse dashboard's stream notices the new arrival and fans out
      // currentPosition onto every waiting doc; we listen to our own doc and
      // the position/wait tiles fill in live the moment it lands.
      final thisLevel = _normalizeLevel(existingData?['triageLevel']);

      if (mounted) {
        setState(() {
          _confirmed = true;
          _queueNumber = queueNumber;
          _showLowPriorityNote = thisLevel == 'LOW';
        });
      }
      _listenToOwnDoc(docRef);

      // ── Notifications (best-effort — never block or crash the check-in) ──────
      // The patient's own position notification comes from the staff-side
      // fan-out (which knows the real rank) — only the nurses are told here.
      try {
        final patientName =
            FirebaseAuth.instance.currentUser?.displayName?.trim() ??
            'A patient';
        final noAI = existingData?['noAITriage'] == true;

        await NotificationService().notifyNursePatientArrival(
          patientName: patientName,
          queueNumber: queueNumber,
          reportedSymptoms: !noAI,
        );
      } catch (_) {
        // Notification failure must never surface to the patient.
      }
    } catch (e) {
      if (!mounted) return;
      final isArabicErr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabicErr
                ? "فشل تسجيل الوصول. يرجى المحاولة مرة أخرى عند الاستقبال."
                : "Check-in failed. Please try again at reception.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  String _normalizeLevel(dynamic raw) {
    final level = (raw as String?)?.toUpperCase() ?? 'LOW';
    if (level == 'EMERGENCY' || level == 'MODERATE' || level == 'LOW') {
      return level;
    }
    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          isArabic ? 'تسجيل الوصول' : 'Check In',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: _confirmed
            ? _buildSuccessState(isArabic)
            : _buildPreConfirmState(isArabic),
      ),
    );
  }

  // ── POST-CONFIRM ────────────────────────────────────────────────────────────

  Widget _buildSuccessState(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200, width: 3),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 64,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              isArabic ? "تم تسجيل وصولك!" : "You're checked in!",
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              isArabic
                  ? "ستتم رؤيتك من قِبَل ممرضة قريباً. يرجى الجلوس في منطقة الانتظار."
                  : "A nurse will see you shortly. Please take a seat in the waiting area.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    isArabic ? "رقم طابورك" : "Your Queue Number",
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _queueNumber,
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _queueInfo(
                          isArabic ? "الترتيب" : "Position",
                          _waitPosition == null ? "-" : "#$_waitPosition",
                          isArabic,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _queueInfo(
                          isArabic ? "وقت الانتظار المتوقع" : "Estimated Wait",
                          _estimatedWaitText,
                          isArabic,
                        ),
                      ),
                    ],
                  ),

                  if (_showLowPriorityNote) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isArabic
                            ? "قد يزداد وقت الانتظار عند وصول حالات طارئة."
                            : "May increase if emergency patients arrive.",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  isArabic ? "العودة للرئيسية" : "Back to Home",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueInfo(String label, String value, bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── PRE-CONFIRM ─────────────────────────────────────────────────────────────

  Widget _buildPreConfirmState(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? "لقد وصلت" : "I Have Arrived",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Text(
            isArabic
                ? "وصلت إلى المستشفى؟ سجّل وصولك هنا لتجاوز طابور الاستقبال."
                : "Already at the hospital? Check in here to skip the reception queue.",
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 40),

          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.teal.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.teal,
                  size: 40,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmArrival,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.pan_tool, size: 22),
              label: Text(
                _isConfirming
                    ? (isArabic ? "جارٍ التسجيل…" : "Checking in…")
                    : (isArabic ? "لقد وصلت" : "I Have Arrived"),
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              isArabic
                  ? "اضغط للتسجيل يدوياً عند وصولك للمستشفى"
                  : "Tap to manually check in at the hospital",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  isArabic ? "أو" : "OR",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 26),

          // Auto-detect card — GPS not yet implemented
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.teal),
                      const SizedBox(width: 12),
                      Text(
                        isArabic
                            ? "الكشف التلقائي عن الموقع"
                            : "Auto-Detect Location",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic
                        ? "فعّل GPS ليتم اكتشاف وصولك تلقائياً عند اقترابك من المستشفى."
                        : "Enable GPS to automatically detect when you're near the hospital for instant check-in.",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.location_searching,
                        color: Colors.teal,
                      ),
                      label: Text(
                        isArabic ? "قريباً" : "Coming Soon",
                        style: const TextStyle(color: Colors.teal),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.teal.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isArabic
                  ? "استخدم هذا الخيار عند وصولك للمستشفى بعد إكمال تقييم الأعراض. لا حاجة للانتظار عند طاولة الاستقبال."
                  : "Use this when you arrive at the hospital after completing your symptom assessment. No need to wait at the reception desk.",
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
