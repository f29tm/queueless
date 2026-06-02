import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizer.dart';

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

  // ── Estimated-wait model (APQ — accumulative priority queue) ──────────────
  // Constants derived from published KTAS/CTAS/ESI time-to-be-seen targets,
  // cross-checked against the project dataset's median ED length-of-stay per
  // acuity level (Emergency 479 min > Urgent 323 > Non-Urgent 180), which
  // confirms the acuity->resource gradient. The per-patient service minutes
  // below are in-lane service estimates, NOT raw LOS.
  //
  // Per-patient in-lane service time (minutes), by triage class.
  // Basis: KTAS/ESI published targets (L1 immediate, L2 10m, L3 30m,
  // L4 60m, L5 120m) scaled for parallel multi-bay service; dataset median
  // LOS confirms ordering.
  static const Map<String, int> _serviceMinutes = {
    'EMERGENCY': 12,
    'MODERATE': 20,
    'LOW': 25,
  };
  static const double _rangeSpread = 0.25; // +/- 25% shown as a range

  @override
  void initState() {
    super.initState();
    _resolvedDocId = widget.queueDocId;
    if (_resolvedDocId == null) {
      _lookupPendingDoc();
    }
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
      }
    } catch (_) {}
  }

  Future<void> _confirmArrival() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_resolvedDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "لا يوجد طلب فرز معلق. أكمل تقييم الأعراض أولاً."
                : "No pending triage found. Complete symptom assessment first.",
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
      final queueNumber = existingData?['queueNumber'] as String? ??
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

      final waiting = await FirebaseFirestore.instance
          .collection('queue')
          .where('queueType', isEqualTo: 'nurse')
          .where('status', isEqualTo: 'waiting_nurse')
          .orderBy('priorityNumber')
          .orderBy('createdAt')
          .get();
      final index =
          waiting.docs.indexWhere((doc) => doc.id == _resolvedDocId);
      final patientsAhead = index < 0 ? 0 : index;

      // APQ estimate: only patients ahead in line with equal-or-higher
      // priority contribute to this patient's in-lane wait.
      final thisLevel = _normalizeLevel(existingData?['triageLevel']);
      final myPriority = _priorityRank(thisLevel);
      int patientsAheadInLane = 0;
      for (int i = 0; i < patientsAhead; i++) {
        final aheadData = waiting.docs[i].data();
        final aheadPriority =
            (aheadData['priorityNumber'] as num?)?.toInt() ?? 3;
        if (aheadPriority <= myPriority) patientsAheadInLane++;
      }

      final serviceMinutes = _serviceMinutes[thisLevel] ?? 20;
      final baseWait = patientsAheadInLane * serviceMinutes;
      final String waitText;
      if (patientsAheadInLane == 0) {
        waitText = "You're next";
      } else {
        final low = (baseWait * (1 - _rangeSpread)).round();
        final high = (baseWait * (1 + _rangeSpread)).round();
        waitText = "$low–$high min";
      }

      if (mounted) {
        setState(() {
          _confirmed = true;
          _queueNumber = queueNumber;
          _waitPosition = patientsAhead + 1;
          _estimatedWaitText = waitText;
          _showLowPriorityNote = thisLevel == 'LOW';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final isArabicErr =
          Localizations.localeOf(context).languageCode == 'ar';
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

  int _priorityRank(String level) {
    switch (level) {
      case 'EMERGENCY':
        return 1;
      case 'MODERATE':
        return 2;
      default:
        return 3; // LOW / unknown
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

    return Directionality(
      textDirection: AppLocalizer.direction(context),
      child: Scaffold(
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
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 64),
            ),

            const SizedBox(height: 28),

            Text(
              isArabic ? "تم تسجيل وصولك!" : "You're checked in!",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
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
                          _waitPosition == null
                              ? "-"
                              : "#$_waitPosition",
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
                        "May increase if emergency patients arrive.",
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
                          strokeWidth: 2, color: Colors.white),
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
                      color: Colors.grey, fontWeight: FontWeight.bold),
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
                            fontSize: 17, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.location_searching,
                          color: Colors.teal),
                      label: Text(
                        isArabic ? "قريباً" : "Coming Soon",
                        style: const TextStyle(color: Colors.teal),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.teal.withValues(alpha: 0.4)),
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
