import 'package:flutter/material.dart';

/// Bottom action bar for nurse multi-select mode.
///
/// Slides up from the bottom when [active], offering a red "Discharge N
/// patients" button. Returns a [Positioned] so it can be dropped straight into
/// the dashboard's [Stack].
class NurseMultiSelectBar extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onDischarge;

  const NurseMultiSelectBar({
    super.key,
    required this.active,
    required this.count,
    required this.onDischarge,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: active ? Offset.zero : const Offset(0, 1),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: count == 0 ? null : onDischarge,
              icon: const Icon(Icons.exit_to_app),
              label: Text(
                "Discharge $count patient${count == 1 ? '' : 's'}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
