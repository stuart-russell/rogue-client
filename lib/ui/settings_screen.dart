import 'package:flutter/material.dart';

import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import '../theme.dart';
import 'pin_dialog.dart';
import 'updates_panel.dart';
import 'responsive.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final account = model.session.account;
    final catalog = model.catalog;
    final epg = model.epg;
    final prefs = model.preferences;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        pagePadding(context),
        pageTopPadding(context),
        pagePadding(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Settings',
            subtitle: 'Account, playback and local cache',
            trailing: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.only(right: 6, bottom: 30),
                children: [
                  _section('Appearance', [
                    Text(
                      'Applies instantly and is remembered on this device.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Two-up on phones; a single row of fixed cards elsewhere.
                        final width = isCompact(context)
                            ? (constraints.maxWidth - 10) / 2
                            : 172.0;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final palette in kPalettes)
                              _PaletteCard(
                                palette: palette,
                                width: width,
                                selected: prefs.paletteId == palette.id,
                                onTap: () => _setPalette(model, palette),
                              ),
                          ],
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Updates', [const UpdatesPanel()]),
                  const SizedBox(height: 14),
                  _section('Account', [
                    _kv(
                      'Server',
                      model.session.server.isEmpty ? '—' : model.session.server,
                    ),
                    _kv('Username', model.session.username),
                    _kv('Status', account?.status ?? 'Active'),
                    _kv(
                      'Expires',
                      account?.expiresAt == null
                          ? 'No expiry reported'
                          : _date(account!.expiresAt!),
                    ),
                    _kv(
                      'Connections',
                      account == null
                          ? '—'
                          : '${account.activeConnections} active of ${account.maxConnections}',
                    ),
                    _kv(
                      'Formats',
                      account == null || account.allowedFormats.isEmpty
                          ? '—'
                          : account.allowedFormats.join(', '),
                    ),
                    if (account?.timezone != null)
                      _kv('Panel timezone', account!.timezone!),
                  ]),
                  const SizedBox(height: 14),
                  _section('Playback', [
                    Text(
                      'Live streams are served as raw MPEG-TS or HLS. If a channel fails to start, or seeking on catch-up misbehaves, try the other format.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Live format',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'ts', label: Text('MPEG-TS')),
                            ButtonSegment(value: 'm3u8', label: Text('HLS')),
                          ],
                          selected: {model.preferences.liveExtension},
                          onSelectionChanged: (selection) => model.preferences
                              .setLiveExtension(selection.first),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? AppColors.accent.withValues(alpha: 0.18)
                                  : AppColors.surface,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              AppColors.text,
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'VOD and series always use the container extension reported by the panel.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Parental controls', [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hide adult content',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Hides adult categories from the guide, movies, series and search. '
                                'Turning the filter off requires the PIN.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: prefs.adultFilterEnabled,
                          onChanged: (value) => _setAdultFilter(model, value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _changePin(model),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.pin_outlined, size: 16),
                          label: Text(
                            prefs.hasAdultPin ? 'Change PIN' : 'Set PIN',
                          ),
                        ),
                        if (prefs.hasAdultPin)
                          TextButton(
                            onPressed: () => _removePin(model),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                            ),
                            child: const Text('Remove PIN'),
                          ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Guide', [
                    _kv('Programmes', '${epg.programmeCount}'),
                    _kv(
                      'Last updated',
                      epg.updatedAt == null
                          ? 'Never'
                          : _dateTime(epg.updatedAt!),
                    ),
                    if (epg.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          epg.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Download guide on launch',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Fetches the panel XMLTV in the background and caches it.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: model.preferences.autoDownloadGuide,
                                onChanged: (value) => model.preferences
                                    .setAutoDownloadGuide(value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: epg.loading
                              ? null
                              : () => _run(() => epg.load(force: true)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: Text(epg.loading ? 'Updating…' : 'Update now'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: epg.loading ? null : () => _run(epg.clear),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                          ),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Catalogue', [
                    _kv(
                      'Channels',
                      '${catalog.countFor(CatalogSegment.live, null)}',
                    ),
                    _kv(
                      'Movies',
                      '${catalog.countFor(CatalogSegment.vod, null)}',
                    ),
                    _kv(
                      'Series',
                      '${catalog.countFor(CatalogSegment.series, null)}',
                    ),
                    _kv(
                      'Last refreshed',
                      catalog.updatedAt == null
                          ? 'Never'
                          : _dateTime(catalog.updatedAt!),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: catalog.busy
                            ? null
                            : () => _run(catalog.refreshAll),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: Text(
                          catalog.busy ? 'Refreshing…' : 'Refresh everything',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Storage', [
                    FutureBuilder<int>(
                      future: model.cache.totalBytes(),
                      builder: (context, snapshot) => _kv(
                        'Cache on disk',
                        snapshot.hasData ? formatBytes(snapshot.data!) : '…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _run(() async {
                          await model.cache.removeAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cache cleared. Catalogues will reload on next launch.',
                                ),
                              ),
                            );
                          }
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                        ),
                        label: const Text('Clear cached data'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Session', [
                    Text(
                      'Signing out removes the saved panel credentials from this device.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _confirmLogout(context, model),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceHigh,
                          foregroundColor: AppColors.text,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 17),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  Center(
                    child: Column(
                      children: [
                        AppMark(size: 13, showDot: false),
                        SizedBox(height: 8),
                        Text(
                          'Rogue 1.0.0 · independent Xtream client\nNot affiliated with your provider.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setPalette(AppModel model, Palette palette) async {
    await model.preferences.setPalette(palette.id);
    if (mounted) _snack('Theme set to ${palette.name}.');
  }

  Future<void> _setAdultFilter(AppModel model, bool value) async {
    final prefs = model.preferences;
    if (value) {
      if (!prefs.hasAdultPin) {
        final pin = await showPinDialog(
          context,
          title: 'Set a PIN',
          message: 'Choose a 4–8 digit PIN. You will need it to show adult content again.',
          confirm: true,
        );
        if (pin == null) return;
        await prefs.setAdultPin(pin);
      }
      await prefs.setAdultFilterEnabled(true);
      model.catalog.setAdultFilter(true);
      if (mounted) _snack('Adult content hidden.');
      return;
    }

    final pin = await showPinDialog(
      context,
      title: 'Enter PIN',
      message: 'Enter your PIN to show adult content again.',
    );
    if (pin == null) return;
    if (!prefs.verifyAdultPin(pin)) {
      if (mounted) _snack('Incorrect PIN.');
      return;
    }
    await prefs.setAdultFilterEnabled(false);
    model.catalog.setAdultFilter(false);
    if (mounted) _snack('Adult content visible again.');
  }

  Future<void> _changePin(AppModel model) async {
    final prefs = model.preferences;
    if (prefs.hasAdultPin) {
      final current = await showPinDialog(context, title: 'Enter current PIN');
      if (current == null) return;
      if (!prefs.verifyAdultPin(current)) {
        if (mounted) _snack('Incorrect PIN.');
        return;
      }
    }
    if (!mounted) return;
    final pin = await showPinDialog(
      context,
      title: 'Set a PIN',
      message: 'Choose a 4–8 digit PIN.',
      confirm: true,
    );
    if (pin == null) return;
    await prefs.setAdultPin(pin);
    if (mounted) _snack('PIN saved.');
  }

  Future<void> _removePin(AppModel model) async {
    final prefs = model.preferences;
    final pin = await showPinDialog(
      context,
      title: 'Enter PIN',
      message: 'Removing the PIN also shows adult content again.',
    );
    if (pin == null) return;
    if (!prefs.verifyAdultPin(pin)) {
      if (mounted) _snack('Incorrect PIN.');
      return;
    }
    await prefs.clearAdultPin();
    await prefs.setAdultFilterEnabled(false);
    model.catalog.setAdultFilter(false);
    if (mounted) _snack('PIN removed.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(width: 320, content: Text(message)));
  }

  Widget _section(String title, List<Widget> children) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isCompact(context) ? 112 : 150,
            child: Text(
              key,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 12.5, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmLogout(BuildContext context, AppModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: const Text('Sign out?'),
        content: const Text(
          'Saved panel credentials will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await model.logout();
    }
  }
}

/// A clickable swatch in Settings' Appearance section.
class _PaletteCard extends StatefulWidget {
  const _PaletteCard({
    required this.palette,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PaletteCard> createState() => _PaletteCardState();
}

class _PaletteCardState extends State<_PaletteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final selected = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : (_hovered ? palette.border.withValues(alpha: 1) : palette.border.withValues(alpha: 0.7)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _swatch(palette.background, 20, radius: 6),
                  const SizedBox(width: 5),
                  _swatch(palette.surfaceHigh, 20, radius: 6),
                  const SizedBox(width: 5),
                  _swatch(palette.accent, 20, circle: true),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 16, color: palette.accent),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                palette.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                palette.tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(Color colour, double size, {double radius = 0, bool circle = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }
}
