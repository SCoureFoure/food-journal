import 'package:flutter/material.dart';

import '../../models/meal_entry.dart';
import '../../models/medication.dart';
import '../../models/reaction_log.dart';
import '../../models/water_log.dart';
import '../../models/weight_log.dart';
import '../../screens/log_water/log_water_sheet.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/error_display.dart';
import '../../widgets/home/week_summary_section.dart';
import '../../widgets/lined_paper_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _settings = SettingsService();

  Map<DateTime, List<MealEntry>> _mealsByDate = {};
  Map<DateTime, List<Medication>> _medsByDate = {};
  Map<DateTime, List<ReactionLog>> _feelingsByDate = {};
  Map<DateTime, List<WaterLog>> _waterByDate = {};
  Map<DateTime, List<WeightLog>> _weightByDate = {};
  List<DateTime> _sortedDates = [];
  bool _loading = true;
  String? _errorMessage;
  bool _fabOpen = false;
  bool _leftHanded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lh = await _settings.isLeftHanded;
    if (mounted) setState(() => _leftHanded = lh);
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _storage.getAllMeals(),
        _storage.getAllMedications(),
        _storage.getStandaloneReactionLogs(),
        _storage.getAllWaterLogs(),
        _storage.getAllWeightLogs(),
      ]);
      final meals = results[0] as List<MealEntry>;
      final meds = results[1] as List<Medication>;
      final feelings = results[2] as List<ReactionLog>;
      final waterLogs = results[3] as List<WaterLog>;
      final weightLogs = results[4] as List<WeightLog>;

      final mealsByDate = <DateTime, List<MealEntry>>{};
      for (final meal in meals) {
        final key = DateTime(meal.date.year, meal.date.month, meal.date.day);
        mealsByDate.putIfAbsent(key, () => []).add(meal);
      }

      final medsByDate = <DateTime, List<Medication>>{};
      for (final med in meds) {
        final key = DateTime(med.date.year, med.date.month, med.date.day);
        medsByDate.putIfAbsent(key, () => []).add(med);
      }

      final feelingsByDate = <DateTime, List<ReactionLog>>{};
      for (final log in feelings) {
        final key = DateTime(log.checkinTime.year, log.checkinTime.month, log.checkinTime.day);
        feelingsByDate.putIfAbsent(key, () => []).add(log);
      }

      final waterByDate = <DateTime, List<WaterLog>>{};
      for (final log in waterLogs) {
        final key = DateTime(log.date.year, log.date.month, log.date.day);
        waterByDate.putIfAbsent(key, () => []).add(log);
      }

      final weightByDate = <DateTime, List<WeightLog>>{};
      for (final log in weightLogs) {
        final key = DateTime(log.date.year, log.date.month, log.date.day);
        weightByDate.putIfAbsent(key, () => []).add(log);
      }

      final allDates = {
        ...mealsByDate.keys,
        ...medsByDate.keys,
        ...feelingsByDate.keys,
        ...waterByDate.keys,
        ...weightByDate.keys,
      }.toList()..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _mealsByDate = mealsByDate;
        _medsByDate = medsByDate;
        _feelingsByDate = feelingsByDate;
        _waterByDate = waterByDate;
        _weightByDate = weightByDate;
        _sortedDates = allDates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  List<({DateTime weekStart, List<DateTime> dates})> _weekGroups() {
    final Map<DateTime, List<DateTime>> byWeek = {};
    for (final date in _sortedDates) {
      final ws = _mondayOf(date);
      byWeek.putIfAbsent(ws, () => []).add(date);
    }
    final sortedStarts = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedStarts.map((ws) {
      final dates = byWeek[ws]!..sort((a, b) => b.compareTo(a));
      return (weekStart: ws, dates: dates);
    }).toList();
  }

  void _closeFab() => setState(() => _fabOpen = false);

  Future<void> _navigate(String route, {Object? arguments}) async {
    _closeFab();
    await Navigator.pushNamed(context, route, arguments: arguments);
    _load();
  }

  Future<void> _showWaterSheet() async {
    _closeFab();
    await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(child: const LogWaterSheet()),
      ),
    );
    _load();
  }

  Future<void> _showSettings() async {
    _closeFab();
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SettingsDialog(settings: _settings),
    );
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'home-screen',
      child: LinedPaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: const Text('Food Journal'),
        actions: [
          Semantics(
            identifier: 'btn-settings',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _showSettings,
              tooltip: 'Settings',
            ),
          ),
          Semantics(
            identifier: 'btn-export',
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => Navigator.pushNamed(context, '/export'),
              tooltip: 'Export',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: _leftHanded
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
    ),
    ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Semantics(
          identifier: 'home-loading',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return ErrorRetry(
        semanticsId: 'home-error',
        message: _errorMessage!,
        onRetry: _load,
      );
    }

    if (_sortedDates.isEmpty) {
      return Center(
        child: Semantics(
          identifier: 'home-empty-state',
          child: const Text('Nothing logged yet.'),
        ),
      );
    }

    final groups = _weekGroups();
    return Semantics(
      identifier: 'home-meal-list',
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: groups.length,
        itemBuilder: (_, i) {
          final group = groups[i];
          return WeekSummarySection(
            weekStart: group.weekStart,
            dates: group.dates,
            mealsByDate: _mealsByDate,
            medsByDate: _medsByDate,
            feelingsByDate: _feelingsByDate,
            waterByDate: _waterByDate,
            weightByDate: _weightByDate,
            storage: _storage,
            isToday: _isToday,
            onReload: _load,
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    const dur = Duration(milliseconds: 200);
    final theme = Theme.of(context);

    final alignment = _leftHanded ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        AnimatedOpacity(
          opacity: _fabOpen ? 1.0 : 0.0,
          duration: dur,
          child: AnimatedSlide(
            offset: _fabOpen ? Offset.zero : const Offset(0, 0.3),
            duration: dur,
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: Column(
                crossAxisAlignment: alignment,
                children: [
                  _MiniFabOption(
                    label: 'Medication',
                    icon: Icons.medication_outlined,
                    color: theme.colorScheme.secondary,
                    onTap: () => _navigate('/log_medication'),
                    leftHanded: _leftHanded,
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Feeling…',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    color: theme.colorScheme.tertiary,
                    onTap: () => _navigate('/checkin'),
                    leftHanded: _leftHanded,
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Weigh-in',
                    icon: Icons.monitor_weight_outlined,
                    color: theme.colorScheme.secondary.withAlpha(180),
                    onTap: () => _navigate('/log_weight'),
                    leftHanded: _leftHanded,
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Water',
                    icon: Icons.water_drop_outlined,
                    color: Colors.blue.shade400,
                    onTap: _showWaterSheet,
                    leftHanded: _leftHanded,
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Food',
                    icon: Icons.restaurant_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => _navigate('/log'),
                    leftHanded: _leftHanded,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          identifier: 'btn-log-entry',
          child: FloatingActionButton(
            onPressed: () => setState(() => _fabOpen = !_fabOpen),
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0.0,
              duration: dur,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

// ── FAB mini option ───────────────────────────────────────────────────────────

class _MiniFabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool leftHanded;

  const _MiniFabOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.leftHanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final slug = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final fab = Semantics(
      identifier: 'btn-fab-$slug',
      child: FloatingActionButton.small(
        heroTag: label,
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: onTap,
        child: Icon(icon, size: 20),
      ),
    );
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: leftHanded
          ? [fab, const SizedBox(width: 8), chip]
          : [chip, const SizedBox(width: 8), fab],
    );
  }
}

// ── Settings dialog ───────────────────────────────────────────────────────────

class _SettingsDialog extends StatefulWidget {
  final SettingsService settings;
  const _SettingsDialog({required this.settings});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool? _aiEnabled;
  bool? _leftHanded;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.settings.isAiEnabled,
      widget.settings.isLeftHanded,
    ]).then((values) {
      if (mounted) {
        setState(() {
          _aiEnabled = values[0];
          _leftHanded = values[1];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = _aiEnabled == null || _leftHanded == null;
    return AlertDialog(
      title: const Text('Settings'),
      content: loading
          ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('AI features'),
                  subtitle: const Text('Autofill with AI on log screens'),
                  value: _aiEnabled!,
                  onChanged: (v) async {
                    await widget.settings.setAiEnabled(v);
                    if (mounted) setState(() => _aiEnabled = v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Left-handed mode'),
                  subtitle: const Text('Move + button to left side'),
                  value: _leftHanded!,
                  onChanged: (v) async {
                    await widget.settings.setLeftHanded(v);
                    if (mounted) setState(() => _leftHanded = v);
                  },
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
