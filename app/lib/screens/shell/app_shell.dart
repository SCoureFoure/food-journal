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
  final _homeKey = GlobalKey<HomeScreenState>();
  final _settings = SettingsService();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'app-shell',
      child: LinedPaperBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            titleSpacing: 8,
            title: FolderTabBar(
              tabs: const [
                FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
                FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
              ],
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
      ),
    );
  }

  List<Widget> _actions() => [
        Semantics(
          identifier: 'btn-settings',
          child: IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ),
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
      ];

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(settings: _settings),
    );
    await _homeKey.currentState?.reloadSettings();
  }
}
