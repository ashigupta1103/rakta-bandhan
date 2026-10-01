import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FilterChipItem {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const FilterChipItem({required this.label, required this.active, required this.onTap});
}

/// Horizontal row of pill filter chips — the prototype's recurring
/// chip-row pattern (nearby requests, request tabs, map, notifications, admin).
class FilterChipRow extends StatelessWidget {
  final List<FilterChipItem> chips;
  final Color activeBg;
  final Color activeText;
  final Color inactiveText;

  const FilterChipRow({
    super.key,
    required this.chips,
    this.activeBg = AppColors.textPrimaryWarm,
    this.activeText = Colors.white,
    this.inactiveText = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: chip.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: chip.active ? activeBg : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: chip.active ? null : Border.all(color: AppColors.warmBorder),
                    boxShadow: const [BoxShadow(color: AppColors.shadowCard, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    chip.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: chip.active ? FontWeight.w600 : FontWeight.w500,
                      color: chip.active ? activeText : inactiveText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
