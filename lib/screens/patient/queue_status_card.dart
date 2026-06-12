import 'package:flutter/material.dart';

import '../../utils/triage_levels.dart';
import '../../utils/wait_estimator.dart';

/// Patient-facing live status card shown at the top of the hub.
///
/// Driven entirely by the patient's own `queue` document (the only one Firestore
/// rules let them read). Stateless and Firebase-free so each status branch is
/// unit-testable; the hub wraps it in a StreamBuilder and supplies [onCheckIn].
///
/// Returns an empty [SizedBox] for any status outside the active set, so the
/// hub can hand it whatever the stream yields without pre-filtering.
class QueueStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  /// Invoked by the pre_arrival "Check In Now" button. The hub navigates to the
  /// arrival screen; tests pass a no-op.
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
        return _shell(accent: TriageLevels.color(level), child: _waitingNurse(level));
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
        const Icon(Icons.confirmation_number_outlined,
            color: Colors.teal, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'لديك فرز معلق' : 'You have a pending triage',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        fontSize: 15, fontWeight: FontWeight.bold),
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
    final isNext = position != null && position <= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isArabic ? 'بانتظار تقييم الممرضة' : 'Waiting for nurse assessment',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          queueNumber,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (isNext)
          Text(
            isArabic ? 'أنت التالي!' : "You're next!",
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          )
        else ...[
          Text(
            position == null ? '#-' : '#$position',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            // Position N means N-1 patients ahead in the lane.
            WaitEstimator.waitText(level, (position ?? 1) - 1),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _waitingDoctor() {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'اكتمل تقييم الممرضة' : 'Nurse assessment complete',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
