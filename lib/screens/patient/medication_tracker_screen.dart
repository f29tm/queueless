import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/prescription_service.dart';

// ── Locale-aware label helpers ────────────────────────────────────────────────

String _localizeRemainingLabel(Prescription p, bool isArabic) {
  if (!isArabic) return p.remainingLabel;
  final rem = p.dosesRemaining;
  if (rem == -1) {
    if (p.endDate == null) return 'مستمر';
    final days = p.endDate!.difference(DateTime.now()).inDays;
    if (days <= 0) return 'انتهت الوصفة';
    return 'تجديد خلال $days يوم';
  }
  return 'متبقي $rem جرعة';
}

String _localizeDurationLabel(Prescription p, bool isArabic) {
  if (!isArabic) return p.durationLabel;
  if (p.endDate == null) return 'مستمر';
  final start = _translateMonthAbbr(DateFormat('MMM d').format(p.startDate));
  final end = _translateMonthAbbr(DateFormat('MMM d').format(p.endDate!));
  return '$start – $end';
}

String _translateMonthAbbr(String value) {
  return value
      .replaceAll('Jan', 'يناير')
      .replaceAll('Feb', 'فبراير')
      .replaceAll('Mar', 'مارس')
      .replaceAll('Apr', 'أبريل')
      .replaceAll('May', 'مايو')
      .replaceAll('Jun', 'يونيو')
      .replaceAll('Jul', 'يوليو')
      .replaceAll('Aug', 'أغسطس')
      .replaceAll('Sep', 'سبتمبر')
      .replaceAll('Oct', 'أكتوبر')
      .replaceAll('Nov', 'نوفمبر')
      .replaceAll('Dec', 'ديسمبر');
}

class MedicationTrackerScreen extends StatelessWidget {
  const MedicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(isArabic ? 'المستخدم غير مسجل الدخول' : 'Not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<List<Prescription>>(
        stream: PrescriptionService().streamForPatient(uid),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final all = snapshot.data ?? [];
          final today = all.where((p) => p.isActiveToday).toList();
          final doneToday = today.where((p) => p.allTodayDosesTaken).length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  todayCount: today.length,
                  doneCount: doneToday,
                  loading: loading,
                  isArabic: isArabic,
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  ),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      isArabic
                          ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.'
                          : 'Something went wrong. Please try again.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else if (all.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else ...[
                if (today.isNotEmpty) ...[
                  _sectionHeader(
                    context,
                    isArabic ? 'أدوية اليوم' : "Today's Medications",
                    badge: isArabic
                        ? '$doneToday/${today.length} مكتمل'
                        : '$doneToday/${today.length} done',
                    badgeGreen: doneToday == today.length,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TodayMedCard(prescription: today[i]),
                        childCount: today.length,
                      ),
                    ),
                  ),
                ],
                _sectionHeader(
                  context,
                  isArabic ? 'جميع الوصفات الطبية' : 'All Prescriptions',
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PrescriptionCard(prescription: all[i]),
                      childCount: all.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(
    BuildContext context,
    String title, {
    String? badge,
    bool badgeGreen = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (badge != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeGreen
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeGreen ? Colors.green : Colors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Teal gradient header ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int todayCount;
  final int doneCount;
  final bool loading;
  final bool isArabic;

  const _Header({
    required this.todayCount,
    required this.doneCount,
    required this.loading,
    required this.isArabic,
  });

  String _localizedDate() {
    final raw = DateFormat('EEEE, MMM d').format(DateTime.now());
    if (!isArabic) return raw;
    return raw
        .replaceAll('Saturday', 'السبت')
        .replaceAll('Sunday', 'الأحد')
        .replaceAll('Monday', 'الاثنين')
        .replaceAll('Tuesday', 'الثلاثاء')
        .replaceAll('Wednesday', 'الأربعاء')
        .replaceAll('Thursday', 'الخميس')
        .replaceAll('Friday', 'الجمعة')
        .replaceAll('Jan', 'يناير')
        .replaceAll('Feb', 'فبراير')
        .replaceAll('Mar', 'مارس')
        .replaceAll('Apr', 'أبريل')
        .replaceAll('May', 'مايو')
        .replaceAll('Jun', 'يونيو')
        .replaceAll('Jul', 'يوليو')
        .replaceAll('Aug', 'أغسطس')
        .replaceAll('Sep', 'سبتمبر')
        .replaceAll('Oct', 'أكتوبر')
        .replaceAll('Nov', 'نوفمبر')
        .replaceAll('Dec', 'ديسمبر');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final allDone = todayCount > 0 && doneCount == todayCount;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // back button always on left — swap children order in Arabic
          // so that in RTL Row, back appears on LEFT (last child = left in RTL)
          Row(
            children: isArabic
                ? [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ]
                : [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
          ),
          const SizedBox(height: 16),

          Text(
            isArabic ? 'متتبع الأدوية' : 'Medication Tracker',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _localizedDate(),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),

          if (!loading && todayCount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        allDone
                            ? (isArabic
                                  ? 'أتممت جميع جرعاتك اليوم!'
                                  : 'All done for today!')
                            : isArabic
                            ? 'تم أخذ $doneCount من $todayCount اليوم'
                            : '$doneCount of $todayCount taken today',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${((doneCount / todayCount) * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: doneCount / todayCount,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.withValues(alpha: 0.15),
                    Colors.teal.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 52,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              isArabic ? 'لا توجد وصفات طبية حالياً' : 'No prescriptions yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              isArabic
                  ? 'ستظهر أدويتك هنا\nبعد أن يصفها طبيبك.'
                  : 'Your medications will appear here\nafter your doctor prescribes them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.teal, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'بعد زيارتك، اطلب من طبيبك وصف الأدوية عبر التطبيق.'
                          : 'After your visit, ask your doctor to prescribe medications through the app.',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today medication card ─────────────────────────────────────────────────────

class _TodayMedCard extends StatefulWidget {
  final Prescription prescription;
  const _TodayMedCard({required this.prescription});

  @override
  State<_TodayMedCard> createState() => _TodayMedCardState();
}

class _TodayMedCardState extends State<_TodayMedCard> {
  bool _marking = false;

  Future<void> _markTaken() async {
    if (widget.prescription.allTodayDosesTaken) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _marking = true);
    try {
      await PrescriptionService().markDoseTaken(widget.prescription.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر تسجيل الجرعة. يرجى المحاولة مرة أخرى.'
                  : 'Could not record dose. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = widget.prescription;
    final allDone = p.allTodayDosesTaken;
    final accent = allDone ? Colors.green : Colors.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                allDone ? Icons.check_circle_rounded : Icons.medication_liquid,
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.medicationName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.dosageInstructions,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip(
                        allDone
                            ? (isArabic
                                  ? 'تم أخذ جميع الجرعات'
                                  : 'All doses taken')
                            : p.nextDoseLabel != null
                            ? (isArabic
                                  ? 'التالية: ${p.nextDoseLabel}'
                                  : 'Next: ${p.nextDoseLabel}')
                            : (isArabic ? 'عند الحاجة' : 'As needed'),
                        color: accent,
                      ),
                      if (!allDone)
                        _chip(
                          isArabic
                              ? '${p.todayDosesTaken}/${p.timesPerDay} اليوم'
                              : '${p.todayDosesTaken}/${p.timesPerDay} today',
                          color: Colors.grey.shade500,
                          light: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            if (allDone)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 22),
              )
            else
              GestureDetector(
                onTap: _marking ? null : _markTaken,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: _marking
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _marking ? Colors.grey.shade200 : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _marking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal,
                          ),
                        )
                      : Text(
                          isArabic ? 'تم' : 'Taken',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {required Color color, bool light = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: light ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Prescription summary card ─────────────────────────────────────────────────

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final p = prescription;
    final warn = p.needsRefill;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: warn
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication,
              color: warn ? Colors.orange : Colors.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.medicationName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.prescribedByName}  ·  ${_localizeDurationLabel(p, isArabic)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: warn
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _localizeRemainingLabel(p, isArabic),
              style: TextStyle(
                color: warn ? Colors.orange.shade800 : Colors.teal.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
