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
            Positioned.fill(child: _FolderBody(color: _tabs[_index].color)),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                titleSpacing: 8,
                // The AppBar centres its title slot, so the bar's base line
                // lands at kTabBaseInToolbar rather than at the toolbar's
                // bottom edge. The folder measures from that constant — it is
                // the tabs the folder has to meet, not the app bar.
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

/// Where the folder's top edge falls: the status bar plus the tab bar's own
/// base line inside the toolbar.
///
/// This lands the edge exactly on the tabs' bottoms. Pulling it any higher puts
/// a coloured band ACROSS the tabs — the folder stops reading as the thing they
/// are attached to and becomes a stripe cutting through them.
double _folderTopInset(BuildContext context) =>
    MediaQuery.of(context).padding.top + kTabBaseInToolbar;

/// The folder body the tabs are attached to: a block of the active tab's colour
/// that begins at the tab's base line and runs down behind the page content,
/// fading out toward the bottom.
///
/// It deliberately starts BELOW the app bar rather than at the top of the
/// screen. A tab sticks up out of its folder — colour above and beside it made
/// the tabs read as floating in a tint instead of being attached to anything.
class _FolderBody extends StatelessWidget {
  final Color color;
  const _FolderBody({required this.color});

  @override
  Widget build(BuildContext context) {
    final topInset = _folderTopInset(context);

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.42,
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Near-solid where it meets the tab so the two read as one
                  // piece of card, then away to nothing.
                  colors: [
                    color.withAlpha(190),
                    color.withAlpha(165),
                    color.withAlpha(0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
