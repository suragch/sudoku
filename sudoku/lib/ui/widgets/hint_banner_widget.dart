import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/deductive_hint.dart';

/// A modern two-stage interactive hint banner that teaches deduction techniques.
class HintBannerWidget extends StatelessWidget {
  final SudokuController controller;

  const HintBannerWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hint = controller.activeHint;
    if (!controller.isHintActive || hint == null) {
      return const SizedBox.shrink();
    }

    final isStage1 = controller.hintStage == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? (isStage1 ? const Color(0xFF272115) : const Color(0xFF142820))
        : (isStage1 ? const Color(0xFFFEF9C3) : const Color(0xFFDCFCE7));

    final borderColor = isStage1 ? Colors.amber.shade500 : const Color(0xFF10B981);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                isStage1 ? Icons.lightbulb_rounded : Icons.check_circle_rounded,
                color: borderColor,
                size: 20,
              ),
              const SizedBox(width: 8),

              // Technique Name Chip
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    hint.techniqueName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Stage Indicator
              Text(
                isStage1 ? 'Where to Look' : 'Explanation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),

              const SizedBox(width: 8),

              // Dismiss X button
              InkWell(
                onTap: controller.dismissHint,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Message Body
          Text(
            isStage1 ? hint.clueMessage : _buildExplanationText(hint),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            ),
          ),

          const SizedBox(height: 8),

          // Action Buttons
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (isStage1) ...[
                  TextButton(
                    onPressed: controller.dismissHint,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text("I'll solve it"),
                  ),
                  FilledButton.icon(
                    onPressed: controller.revealHint,
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Reveal Answer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: controller.dismissHint,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                    child: const Text('Got it'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildExplanationText(DeductiveHint hint) {
    if (hint.targetValue != null) {
      return hint.explanationMessage;
    }
    final cellVal = controller.board.cellAt(hint.targetRow, hint.targetCol).value;
    if (cellVal != 0) {
      return '${hint.explanationMessage}\n(Row ${hint.targetRow + 1}, Column ${hint.targetCol + 1} revealed as $cellVal)';
    }
    return hint.explanationMessage;
  }
}
