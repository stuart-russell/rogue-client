import 'package:flutter/material.dart';

import '../state/watch_progress.dart';
import '../theme.dart';
import 'widgets.dart';

/// Asks whether to resume a partially watched item.
///
/// Returns the position to start from, or null when the user dismisses the
/// dialog (playback should then be cancelled).
Future<Duration?> showResumeDialog(
  BuildContext context,
  WatchEntry entry,
  String title,
) {
  return showDialog<Duration>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.backgroundElevated,
      title: const Text('Resume playback?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'You stopped at ${stampDuration(entry.position)} of ${stampDuration(entry.duration)} '
            '· ${(entry.fraction * 100).round()}% watched.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: entry.fraction,
              minHeight: 5,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, Duration.zero),
          child: const Text('From start'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, entry.position),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Resume'),
        ),
      ],
    ),
  );
}
