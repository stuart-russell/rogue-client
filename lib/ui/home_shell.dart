import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_model.dart';
import '../theme.dart';
import 'live_guide_screen.dart';
import 'favourites_screen.dart';
import 'movies_screen.dart';
import 'recents_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = <_Destination>[
  _Destination('TV Guide', Icons.live_tv_outlined, Icons.live_tv_rounded),
  _Destination('Movies', Icons.movie_outlined, Icons.movie_rounded),
  _Destination(
    'Series',
    Icons.video_library_outlined,
    Icons.video_library_rounded,
  ),
  _Destination('Search', Icons.search_rounded, Icons.search_rounded),
  _Destination('Recents', Icons.history_rounded, Icons.history_rounded),
  _Destination(
    'Favourites',
    Icons.favorite_border_rounded,
    Icons.favorite_rounded,
  ),
  _Destination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Debug-only: `ROGUE_TAB=0..5` opens that tab on launch (QA and screenshots).
  static int _initialIndex() {
    if (!kDebugMode) return 0;
    final raw = Platform.environment['ROGUE_TAB'];
    return (int.tryParse(raw ?? '') ?? 0).clamp(0, 6);
  }

  late int _index = _initialIndex();
  bool _bootstrapped = false;
  late final Set<int> _visited = {_index};

  List<Widget> _buildPages() => [
    LiveGuideScreen(active: _index == 0),
    const MoviesScreen(),
    const SeriesScreen(),
    const SearchScreen(),
    const RecentsScreen(),
    const FavouritesScreen(),
    const SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final model = AppScope.read(context);
      await model.catalog.loadAll();
      if (!mounted) return;
      if (!model.epg.hasData) {
        model.epg.load();
      }
    });
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final pages = _buildPages();

    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _select(3),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            _select(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            _select(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _select(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            _select(3),
      },
      // No Focus wrapper here: an invisible full-size focus node intercepted
      // D-pad traversal, so content items could not be reached from the sidebar.
      child: Column(
        children: [
          if (model.catalog.busy || model.epg.loading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: AppColors.accent,
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < pages.length; i++)
                  _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(index: _index, onSelect: _select, model: model),
            VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: content),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index <= 3 ? _index : 4,
        height: 62,
        backgroundColor: AppColors.backgroundElevated,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 4) {
            _showMore(context);
          } else {
            _select(index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined, size: 22),
            selectedIcon: Icon(Icons.live_tv_rounded, size: 22),
            label: 'Guide',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined, size: 22),
            selectedIcon: Icon(Icons.movie_rounded, size: 22),
            label: 'Movies',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined, size: 22),
            selectedIcon: Icon(Icons.video_library_rounded, size: 22),
            label: 'Series',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded, size: 22),
            selectedIcon: Icon(Icons.search_rounded, size: 22),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded, size: 22),
            selectedIcon: Icon(Icons.more_horiz_rounded, size: 22),
            label: 'More',
          ),
        ],
      ),
    );
  }

  /// Recents, favourites and settings live behind "More" on phones: six tabs
  /// plus a settings FAB was too cramped to hit.
  Future<void> _showMore(BuildContext context) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (4, 'Recents', Icons.history_rounded),
              (5, 'Favourites', Icons.favorite_rounded),
              (6, 'Settings', Icons.settings_rounded),
            ])
              ListTile(
                leading: Icon(
                  entry.$3,
                  color: _index == entry.$1
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                title: Text(
                  entry.$2,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _index == entry.$1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _index == entry.$1
                        ? AppColors.accent
                        : AppColors.text,
                  ),
                ),
                onTap: () => Navigator.pop(context, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null && mounted) _select(choice);
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.onSelect,
    required this.model,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final account = model.session.account;
    final days = account?.daysRemaining;

    return Container(
      width: 224,
      color: AppColors.backgroundElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: AppMark(size: 19),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _destinations.length; i++) ...[
                  if (i == 6)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                  _SidebarTile(
                    destination: _destinations[i],
                    selected: index == i,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
          if (account != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            model.session.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MetaChip(
                          label: days == null ? 'No expiry' : '$days days left',
                          color: days != null && days <= 7
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        MetaChip(
                          label:
                              '${account.activeConnections}/${account.maxConnections}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final hovered = _hovered;
    final focused = _focused;

    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.13)
                : focused
                ? AppColors.surfaceHigh
                : hovered
                ? AppColors.surface.withValues(alpha: 0.8)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: focused ? AppColors.accent : Colors.transparent,
                width: 1.4,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? widget.destination.selectedIcon
                          : widget.destination.icon,
                      size: 19,
                      color: selected ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.destination.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
