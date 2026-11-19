import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';
import 'focusable_tap.dart';
import 'widgets.dart';

/// A phone-sized channel row: logo, name, now/next and live progress.
///
/// The desktop guide uses a timeline grid; on phones that grid needs more width
/// than the screen has, so the guide falls back to this list.
class CompactChannelTile extends StatelessWidget {
  const CompactChannelTile({
    super.key,
    required this.channel,
    required this.programme,
    required this.next,
    required this.onTap,
    required this.onLongPress,
  });

  final LiveStream channel;
  final Programme? programme;
  final Programme? next;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPress;

  @override
  Widget build(BuildContext context) {
    final airing = programme;
    final now = DateTime.now();
    final fraction = airing == null
        ? null
        : (now.difference(airing.start).inSeconds /
                  airing.stop.difference(airing.start).inSeconds)
              .clamp(0.0, 1.0);

    return FocusableTap(
      onTap: onTap,
      onLongPressStart: (details) => onLongPress(details.globalPosition),
      builder: (context, focused) => Container(
        decoration: BoxDecoration(
          color: focused ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused ? AppColors.accent : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            ChannelAvatar(name: channel.name, image: channel.icon, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    airing?.title ?? 'No guide data',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: airing == null
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                  if (airing != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 3,
                              backgroundColor: AppColors.border,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_clock(airing.start)} – ${_clock(airing.stop)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ] else if (next != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Next: ${next!.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.play_circle_outline_rounded,
              size: 26,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
