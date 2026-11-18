import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

/// Modal dialog shown before a user pauses a live premiere.
class PausePremiereDialog extends StatefulWidget {
  const PausePremiereDialog({
    required this.pausesRemaining,
    required this.onKeepWatching,
    required this.onConfirmPause,
    super.key,
  });

  final int pausesRemaining;
  final VoidCallback onKeepWatching;
  final VoidCallback onConfirmPause;

  static Future<void> show(
    BuildContext context, {
    required int pausesRemaining,
    required VoidCallback onKeepWatching,
    required VoidCallback onConfirmPause,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PausePremiereDialog(
        pausesRemaining: pausesRemaining,
        onKeepWatching: onKeepWatching,
        onConfirmPause: onConfirmPause,
      ),
    );
  }

  @override
  State<PausePremiereDialog> createState() => _PausePremiereDialogState();
}

class _PausePremiereDialogState extends State<PausePremiereDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final nextLeft = widget.pausesRemaining > 0 ? widget.pausesRemaining - 1 : 0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pause the premiere?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You’ll have $nextLeft ${nextLeft == 1 ? 'pause' : 'pauses'} left. '
              'The premiere keeps going live while you’re away.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep Watching',
                    style: AppButtonStyle.outline,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onKeepWatching();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Pause',
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirmPause();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _dontShowAgain,
                      activeColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      onChanged: (val) =>
                          setState(() => _dontShowAgain = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Don’t show this again',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
