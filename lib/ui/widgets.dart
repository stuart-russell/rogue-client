import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'focusable_tap.dart';

final _timeFormat = DateFormat.Hm();
final _dayFormat = DateFormat('EEE d MMM');

String clock(DateTime time) => _timeFormat.format(time);
String dayLabel(DateTime time) => _dayFormat.format(time);

String timeRange(DateTime start, DateTime stop) =>
    '${_timeFormat.format(start)} – ${_timeFormat.format(stop)}';

String stampDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Turns a panel-relative image path into something [CachedNetworkImage] can load.
String? resolvePanelImage(BuildContext context, String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return AppScope.read(context).session.api?.absolute(value) ?? value;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 20, this.showDot = true});

  final double size;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROGUE',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: size * 0.42,
            color: AppColors.text,
          ),
        ),
        if (showDot) ...[
          const SizedBox(width: 3),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tint),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search…',
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Move the D-pad out of the text field instead of leaving it in the caret.
  /// The remote still needs Left/Right for editing; Up/Down are free.
  void _leaveField(TraversalDirection direction) {
    Actions.invoke(context, DirectionalFocusIntent(direction));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _leaveField(TraversalDirection.down);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _leaveField(TraversalDirection.up);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        // Left at the start of the text (including an empty field) should
        // leave the field rather than trapping focus in the caret.
        final leftSelection = widget.controller.selection;
        if (!leftSelection.isValid || leftSelection.baseOffset <= 0) {
          _leaveField(TraversalDirection.left);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowRight:
        final textLength = widget.controller.text.length;
        final rightSelection = widget.controller.selection;
        if (!rightSelection.isValid ||
            rightSelection.baseOffset >= textLength) {
          _leaveField(TraversalDirection.right);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.escape:
        node.unfocus();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      // Runs before EditableText unfocuses the field (onSubmitted runs after),
      // so the keyboard's Search/Done action lands on the results.
      onEditingComplete: () => _leaveField(TraversalDirection.down),
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.65),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.accent, width: 1.3),
        ),
      ),
    );
  }
}

class WatchedBadge extends StatelessWidget {
  const WatchedBadge({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.66,
        color: const Color(0xFF06210F),
      ),
    );
  }
}

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.name,
    this.image,
    this.size = 46,
  });

  final String name;
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _initials(name);
    final resolved = resolvePanelImage(context, image);
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (resolved != null)
          ? CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.contain,
              memCacheWidth: (size * 2.4).round(),
              placeholder: (_, _) =>
                  Text(fallback, style: _initialsStyle(size)),
              errorWidget: (_, _, _) =>
                  Text(fallback, style: _initialsStyle(size)),
            )
          : Text(fallback, style: _initialsStyle(size)),
    );
    return box;
  }

  TextStyle _initialsStyle(double size) => TextStyle(
    fontSize: size * 0.32,
    fontWeight: FontWeight.w800,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.image,
    this.subtitle,
    this.aspectRatio = 0.68,
    this.badge,
    this.progress,
    this.watched = false,
    this.onContextMenu,
  });

  final String title;
  final String? subtitle;
  final String? image;
  final VoidCallback onTap;
  final double aspectRatio;
  final Widget? badge;

  /// 0..1 watch progress; draws a thin bar along the bottom of the artwork.
  final double? progress;

  /// Watched to the end: draws a green check badge.
  final bool watched;

  /// Long-press (touch) or right-click (desktop) position.
  final ValueChanged<Offset>? onContextMenu;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final resolved = resolvePanelImage(context, widget.image);
    return FocusableTap(
      onTap: widget.onTap,
      onLongPressStart: widget.onContextMenu == null
          ? null
          : (details) => widget.onContextMenu!(details.globalPosition),
      onSecondaryTapUp: widget.onContextMenu == null
          ? null
          : (details) => widget.onContextMenu!(details.globalPosition),
      builder: (context, focused) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _hovered || focused ? 1.025 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hovered || focused
                          ? AppColors.accent.withValues(alpha: 0.75)
                          : AppColors.border,
                    ),
                    boxShadow: _hovered || focused
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : const [],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (resolved != null)
                        CachedNetworkImage(
                          imageUrl: resolved,
                          fit: BoxFit.cover,
                          memCacheWidth: 420,
                          placeholder: (_, _) =>
                              ColoredBox(color: AppColors.surfaceHigh),
                          errorWidget: (_, _, _) => const _PosterFallback(),
                        )
                      else
                        const _PosterFallback(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.72),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.badge != null)
                        Positioned(top: 8, left: 8, child: widget.badge!),
                      if (widget.watched)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: WatchedBadge(),
                        ),
                      if (widget.progress != null &&
                          widget.progress! > 0.02 &&
                          widget.progress! < 0.98)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 3,
                            backgroundColor: Colors.black54,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceHigh,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: AppColors.textMuted,
          size: 26,
        ),
      ),
    );
  }
}

class StatusPane extends StatelessWidget {
  const StatusPane({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.accent,
                ),
              )
            else
              Icon(icon, size: 34, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(padding: padding, decoration: glassPanel(), child: child);
  }
}
