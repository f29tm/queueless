import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/triage_levels.dart';
import '../../utils/wait_estimator.dart';

/// Patient-facing live status card shown at the top of the hub.
///
/// Driven by the patient's own `queue` document. It deliberately never sits
/// "frozen": each lifecycle state either shows actionable information or the
/// card collapses to nothing.
///
/// - `pre_arrival`  → pending-triage prompt with a Check-In button.
/// - `waiting_nurse`→ queue number + live position/wait. While the position is
///   still being fanned out it shows a brief spinner, then (after a few
///   seconds with no result) a calm "you're checked in" message so it can
///   never spin forever if no staff session is online to compute positions.
/// - `waiting_doctor`→ a short "assessment complete" confirmation that shows
///   the completion time and an ✕ to dismiss, and auto-collapses a few minutes
///   after the nurse finalized (patient-facing tracking ends at the handoff).
/// - anything else (terminal/empty) → renders nothing; the hub falls back to
///   its normal layout and a one-time banner announces discharge/completion.
class QueueStatusCard extends StatefulWidget {
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
  State<QueueStatusCard> createState() => _QueueStatusCardState();
}

class _QueueStatusCardState extends State<QueueStatusCard> {
  // ── Tunables (confirmed in design grilling) ─────────────────────────────────
  /// How long the "Calculating your position…" spinner shows before it gives
  /// up and switches to the calm checked-in fallback.
  static const _positionFallbackDelay = Duration(seconds: 3);

  /// How long after the nurse finalized the "assessment complete" confirmation
  /// stays before the card auto-collapses.
  static const _handoffWindow = Duration(minutes: 3);

  Timer? _positionTimer;
  Timer? _handoffTimer;

  /// True once the position has failed to land within [_positionFallbackDelay].
  bool _positionTimedOut = false;

  /// True once the patient taps ✕ on the handoff confirmation. Reset per doc
  /// because the hub keys this widget by the queue doc id.
  bool _handoffDismissed = false;

  @override
  void initState() {
    super.initState();
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant QueueStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimers();
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _handoffTimer?.cancel();
    super.dispose();
  }

  /// (Re)arm or cancel the per-state timers whenever the doc data changes.
  void _syncTimers() {
    final status = widget.data['status'] as String?;

    // ── Position fallback: only while waiting_nurse with no computed position.
    final hasPosition = (widget.data['currentPosition'] as num?) != null;
    if (status == 'waiting_nurse' && !hasPosition) {
      _positionTimer ??= Timer(_positionFallbackDelay, () {
        if (mounted) setState(() => _positionTimedOut = true);
      });
    } else {
      _positionTimer?.cancel();
      _positionTimer = null;
      // Position arrived (or we left the lane) — drop the fallback so a later
      // re-entry starts clean.
      _positionTimedOut = false;
    }

    // ── Handoff auto-collapse: time out the confirmation [_handoffWindow] after
    // the nurse finalized.
    if (status == 'waiting_doctor') {
      final completed = _completedAt();
      if (completed != null) {
        final remaining = _handoffWindow - DateTime.now().difference(completed);
        if (remaining.isNegative) {
          _handoffTimer?.cancel();
          _handoffTimer = null;
        } else {
          _handoffTimer ??= Timer(remaining, () {
            if (mounted) setState(() {});
          });
        }
      }
    } else {
      _handoffTimer?.cancel();
      _handoffTimer = null;
    }
  }

  DateTime? _completedAt() {
    final ts = widget.data['triageCompletedAt'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  /// The handoff confirmation is visible while it's fresh and not dismissed.
  /// A missing timestamp is treated as "show" (defensive — a finalized doc
  /// always carries triageCompletedAt; we never hide one we can't date).
  bool _handoffVisible() {
    if (_handoffDismissed) return false;
    final completed = _completedAt();
    if (completed == null) return true;
    return DateTime.now().difference(completed) < _handoffWindow;
  }

  bool get isArabic => widget.isArabic;
  Map<String, dynamic> get data => widget.data;

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
        // Collapses once the confirmation window passes or the patient
        // dismisses it — the patient does not track the doctor queue.
        if (!_handoffVisible()) return const SizedBox.shrink();
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
                  onPressed: widget.onCheckIn,
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
        ] else if (!_positionTimedOut) ...[
          // Position not yet computed by the fan-out — show briefly, then the
          // calm fallback below takes over so this never spins forever.
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
        ] else ...[
          // No staff session computed a position in time — reassure instead of
          // spinning. The real #position fills in the moment it lands.
          _statusChip(
            icon: Icons.how_to_reg,
            color: TriageLevels.color(level),
            label: isArabic ? 'تم تسجيل وصولك' : "You're checked in",
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'ستستدعيك الممرضة قريباً'
                : 'The nurse will call you shortly',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
    final completed = _completedAt();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              if (completed != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 13, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      (isArabic ? 'اكتمل التقييم: ' : 'Completed at ') +
                          _formatTime(completed),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // ✕ — collapse the confirmation immediately.
        GestureDetector(
          key: const Key('handoffDismiss'),
          onTap: () => setState(() => _handoffDismissed = true),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Icon(Icons.close, color: Colors.grey.shade400, size: 18),
          ),
        ),
      ],
    );
  }

  /// 12-hour clock with a localized AM/PM marker, no intl locale init needed.
  String _formatTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final isAm = dt.hour < 12;
    final marker = isArabic
        ? (isAm ? 'صباحاً' : 'مساءً')
        : (isAm ? 'AM' : 'PM');
    return '$hour12:$minute $marker';
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
