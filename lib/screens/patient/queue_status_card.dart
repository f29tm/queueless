import 'package:flutter/material.dart';

import '../../utils/triage_levels.dart';
import '../../utils/wait_estimator.dart';

/// Patient-facing live status card shown at the top of the hub.
///
/// Driven entirely by the patient's own `queue` document. Stateless and
/// Firebase-free so each status branch is unit-testable; the hub wraps it in
/// a StreamBuilder and supplies [onCheckIn].
class QueueStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  /// Invoked by the pre_arrival "Check In Now" button.
  final VoidCallback? onCheckIn;

  const QueueStatusCard({
    super.key,
    required this.data,
    required this.isArabic,
    this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String?;
    switch (status) {
      case 'pre_arrival':
        return _shell(accent: Colors.teal, child: _preArrival());
      case 'waiting_nurse':
        final level = (data['triageLevel'] as String?) ?? TriageLevels.low;
        return _shell(
          accent: TriageLevels.color(level),
          child: _waitingNurse(level),
        );
      case 'waiting_doctor':
        return _shell(accent: Colors.green, child: _waitingDoctor());
      default:
        return const SizedBox.shrink();
    }
  }

  // ── State bodies ────────────────────────────────────────────────────────────

  Widget _preArrival() {
    return Row(
      children: [
        const Icon(
          Icons.confirmation_number_outlined,
          color: Colors.teal,
          size: 32,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'لديك فرز معلق' : 'You have a pending triage',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isArabic
                    ? 'اضغط للتسجيل عند وصولك للمستشفى'
                    : 'Tap to check in when you arrive',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'سجّل وصولك الآن' : 'Check In Now',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _waitingNurse(String level) {
    final position = (data['currentPosition'] as num?)?.toInt();
    final queueNumber = data['queueNumber'] as String? ?? '-';

    // #1 means the nurse is currently seeing this patient.
    // #2 means the patient immediately ahead is being seen — you're up next.
    // #3+ means there are patients ahead; show a wait estimate.
    final isBeingSeen = position != null && position <= 1;
    final isNext = position == 2;

    // Wait estimate: prefer the staff-computed value fanned out onto this doc
    // (it sums the actual service times of everyone ahead, whatever their
    // acuity). Fall back to a same-level estimate until it lands.
    final estMin = (data['estimatedWaitMinutes'] as num?)?.toInt();
    final patientsAhead = (position == null || position <= 1)
        ? 0
        : position - 1;
    final waitRange = (estMin != null && estMin > 0)
        ? '${WaitEstimator.rangeLow(estMin)}–${WaitEstimator.rangeHigh(estMin)} min'
        : WaitEstimator.waitText(
            level,
            patientsAhead,
            nextLabel: isArabic ? 'أنت التالي' : "You're next",
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Queue number ──
        Text(
          isArabic ? 'رقم طابورك' : 'Your Queue Number',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          queueNumber,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 10),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 10),

        // ── Status row ──
        if (isBeingSeen) ...[
          _statusChip(
            icon: Icons.medical_services,
            color: TriageLevels.color(level),
            label: isArabic ? 'أنت تُرى الآن' : 'Being seen now',
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'الممرضة تقيّمك في هذه اللحظة'
                : 'The nurse is assessing you now',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ] else if (isNext) ...[
          _statusChip(
            icon: Icons.notifications_active,
            color: Colors.green.shade700,
            label: isArabic ? 'أنت التالي' : "You're next",
          ),
          const SizedBox(height: 6),
          Text(
            isArabic ? 'كن مستعداً' : 'Please be ready',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _waitRow(waitRange, level),
        ] else if (position != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'موقعك في الطابور' : 'Your position in queue',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#$position',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _waitRow(waitRange, level),
        ] else ...[
          // Position not yet computed by fan-out.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'جارٍ حساب موقعك…' : 'Calculating your position…',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitRow(String waitRange, String level) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          (isArabic ? 'وقت الانتظار المتوقع: ' : 'Est. wait: ') + waitRange,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _waitingDoctor() {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          color: Colors.green.shade600,
          size: 32,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'اكتمل تقييم الممرضة' : 'Nurse assessment complete',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isArabic
                    ? 'سيتم رؤيتك من قبل طبيب قريباً'
                    : 'You will be seen by a doctor shortly',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared shell ────────────────────────────────────────────────────────────

  Widget _shell({required Color accent, required Widget child}) {
    return Container(
      key: const Key('queueStatusCard'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
