import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/folder_tab_bar.dart';
import '../../widgets/lined_paper_background.dart';
import '../../widgets/settings_dialog.dart';
import '../home/home_screen.dart';
import '../meal_planning/meal_planning_screen.dart';

class AppShell extends StatefulWidget {
  /// Test seam — handed straight to the journal tab so a widget test can mount
  /// the shell without a real sqlite3 connection. Null in production.
  final StorageService? journalStorageOverride;

  const AppShell({super.key, this.journalStorageOverride});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    FolderTab(
      label: 'Food Journal',
      semanticsId: 'tab-food-journal',
      color: kTabFoodJournal,
    ),
    FolderTab(
      label: 'Meal Planning',
      semanticsId: 'tab-meal-planning',
      color: kTabMealPlanning,
    ),
  ];

  final _homeKey = GlobalKey<HomeScreenState>();
  final _settings = SettingsService();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'app-shell',
      child: LinedPaperBackground(
        child: Stack(
          children: [
            Positioned.fill(child: _TabWash(color: _tabs[_index].color)),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                titleSpacing: 8,
                title: FolderTabBar(
                  tabs: _tabs,
                  selectedIndex: _index,
                  onSelected: (i) {
                    if (i != _index) setState(() => _index = i);
                  },
                ),
                actions: _actions(),
              ),
              body: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    key: _homeKey,
                    storageOverride: widget.journalStorageOverride,
                  ),
                  const MealPlanningScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Settings is LAST so it pins to the far right and holds that position on
  // both tabs. The journal-only actions come before it and appear/disappear to
  // its left, so switching tabs never makes the gear jump under your thumb.
  List<Widget> _actions() => [
        if (_index == 0) ...[
          Semantics(
            identifier: 'btn-export',
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _homeKey.currentState?.navigateAndReload('/export'),
              tooltip: 'Export',
            ),
          ),
          Semantics(
            identifier: 'btn-blame-history',
            child: IconButton(
              icon: const Icon(Icons.history_outlined),
              onPressed: () =>
                  _homeKey.currentState?.navigateAndReload('/blame-history'),
              tooltip: 'Blame history',
            ),
          ),
        ],
        Semantics(
          identifier: 'btn-settings',
          child: IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ),
      ];

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(settings: _settings),
    );
    await _homeKey.currentState?.reloadSettings();
  }
}

/// A soft band of the active tab's colour across the top of the page, fading
/// out about a third of the way down, so the page reads as belonging to the
/// tab standing above it.
class _TabWash extends StatelessWidget {
  final Color color;
  const _TabWash({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          heightFactor: 0.34,
          widthFactor: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withAlpha(150), color.withAlpha(0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
