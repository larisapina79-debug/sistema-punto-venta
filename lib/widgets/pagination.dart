
import 'package:flutter/material.dart';

class Pagination extends StatelessWidget {
  const Pagination({
    super.key,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.pageSize = 5,
    this.itemLabel = 'registros',
    this.primaryColor = const Color.fromARGB(255, 99, 183, 196),
    this.borderColor = const Color(0xFFE0E0E0),
    this.visiblePages = 5,
  });

  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int visiblePages;
  final String itemLabel;
  final Color primaryColor;
  final Color borderColor;
  final ValueChanged<int> onPageChanged;

  Widget _pageButton(
    BuildContext context,
    String label, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final isArrow = label == '‹' || label == '›';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? primaryColor
                  : isArrow
                      ? borderColor
                      : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isArrow
              ? Icon(
                  label == '‹'
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 23,
                  color: onTap == null
                      ? Colors.black26
                      : Colors.black,
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final safePage = currentPage.clamp(0, safeTotalPages - 1);

    final start = totalItems == 0 ? 0 : safePage * pageSize;
    final end = (start + pageSize).clamp(0, totalItems);

    final maxStart = safeTotalPages > visiblePages
        ? safeTotalPages - visiblePages
        : 0;

    final first = (safePage - visiblePages ~/ 2)
        .clamp(0, maxStart);

    final last = (first + visiblePages)
        .clamp(0, safeTotalPages);

    final canPrev = safePage > 0;
    final canNext = safePage < safeTotalPages - 1;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          totalItems == 0
              ? 'Mostrando 0 $itemLabel'
              : 'Mostrando ${start + 1} - $end de '
                  '$totalItems $itemLabel',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 13,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pageButton(
              context,
              '‹',
              onTap: canPrev
                  ? () => onPageChanged(safePage - 1)
                  : null,
            ),
            for (int i = first; i < last; i++) ...[
              const SizedBox(width: 5),
              _pageButton(
                context,
                '${i + 1}',
                selected: i == safePage,
                onTap: () => onPageChanged(i),
              ),
            ],
            const SizedBox(width: 5),
            _pageButton(
              context,
              '›',
              onTap: canNext
                  ? () => onPageChanged(safePage + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
