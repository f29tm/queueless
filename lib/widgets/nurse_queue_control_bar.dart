import 'package:flutter/material.dart';

import '../utils/nurse_queue_filter.dart';

/// Horizontal sort + filter control bar shown above the nurse patient list.
///
/// Stateless — the selected sort/filter live in the parent; this widget just
/// renders the chips and reports taps back via [onSortChanged]/[onFilterChanged].
class NurseQueueControlBar extends StatelessWidget {
  final String selectedSort; // 'priority' | 'arrival' | 'wait'
  final String? selectedFilter; // null = All
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String?> onFilterChanged;

  const NurseQueueControlBar({
    super.key,
    required this.selectedSort,
    required this.selectedFilter,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  static const Color _primary = Color(0xFF2446B8);

  static Color _triageColor(String level) {
    switch (level) {
      case 'EMERGENCY':
        return const Color(0xFFC62828);
      case 'MODERATE':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _sortChip('Priority', 'priority'),
            _sortChip('Arrival Time', 'arrival'),
            _sortChip('Wait Time', 'wait'),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.grey.shade300,
            ),
            _filterChip('All', null, _primary),
            _filterChip('Emergency', 'EMERGENCY', _triageColor('EMERGENCY')),
            _filterChip('Urgent', 'MODERATE', _triageColor('MODERATE')),
            _filterChip('Normal', 'LOW', _triageColor('LOW')),
            _filterChip('Manual', NurseQueueFilter.manual, Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = selectedSort == value;
    return _chip(
      label: label,
      selected: selected,
      color: _primary,
      onTap: () => onSortChanged(value),
    );
  }

  Widget _filterChip(String label, String? value, Color color) {
    final selected = selectedFilter == value;
    return _chip(
      label: label,
      selected: selected,
      color: color,
      onTap: () => onFilterChanged(value),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        backgroundColor: Colors.white,
        selectedColor: color,
        side: BorderSide(color: selected ? color : Colors.grey.shade300),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
