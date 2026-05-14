import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../models/medication.dart';
import '../../models/reaction_log.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/food_item_card.dart';

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
  List<DateTime> _sortedDates = [];
  bool _loading = true;
  String? _errorMessage;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      ]);
      final meals = results[0] as List<MealEntry>;
      final meds = results[1] as List<Medication>;
      final feelings = results[2] as List<ReactionLog>;

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
        final key = DateTime(
          log.checkinTime.year, log.checkinTime.month, log.checkinTime.day,
        );
        feelingsByDate.putIfAbsent(key, () => []).add(log);
      }

      final allDates = {
        ...mealsByDate.keys,
        ...medsByDate.keys,
        ...feelingsByDate.keys,
      }.toList()..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _mealsByDate = mealsByDate;
        _medsByDate = medsByDate;
        _feelingsByDate = feelingsByDate;
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

  void _closeFab() => setState(() => _fabOpen = false);

  Future<void> _navigate(String route, {Object? arguments}) async {
    _closeFab();
    await Navigator.pushNamed(context, route, arguments: arguments);
    _load();
  }

  void _showSettings() {
    _closeFab();
    showDialog<void>(
      context: context,
      builder: (ctx) => _SettingsDialog(settings: _settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      return Center(
        child: Semantics(
          identifier: 'home-error',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
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

    return Semantics(
      identifier: 'home-meal-list',
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _sortedDates.length,
        itemBuilder: (_, i) {
          final date = _sortedDates[i];
          return _DateSection(
            date: date,
            meals: _mealsByDate[date] ?? [],
            medications: _medsByDate[date] ?? [],
            feelings: _feelingsByDate[date] ?? [],
            storage: _storage,
            isToday: _isToday(date),
            onReload: _load,
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    const dur = Duration(milliseconds: 200);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniFabOption(
                    label: 'Feeling…',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    color: theme.colorScheme.tertiary,
                    onTap: () => _navigate('/checkin'),
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Medication',
                    icon: Icons.medication_outlined,
                    color: theme.colorScheme.secondary,
                    onTap: () => _navigate('/log_medication'),
                  ),
                  const SizedBox(height: 8),
                  _MiniFabOption(
                    label: 'Food',
                    icon: Icons.restaurant_outlined,
                    color: theme.colorScheme.primary,
                    onTap: () => _navigate('/log'),
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

  const _MiniFabOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
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
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          onPressed: onTap,
          child: Icon(icon, size: 20),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    widget.settings.isAiEnabled.then((v) {
      if (mounted) setState(() => _aiEnabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: _aiEnabled == null
          ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          : SwitchListTile(
              title: const Text('AI features'),
              subtitle: const Text('Autofill with AI on log screens'),
              value: _aiEnabled!,
              onChanged: (v) async {
                await widget.settings.setAiEnabled(v);
                if (mounted) setState(() => _aiEnabled = v);
              },
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

// ── Date section ──────────────────────────────────────────────────────────────

class _DateSection extends StatefulWidget {
  final DateTime date;
  final List<MealEntry> meals;
  final List<Medication> medications;
  final List<ReactionLog> feelings;
  final StorageService storage;
  final bool isToday;
  final VoidCallback onReload;

  const _DateSection({
    required this.date,
    required this.meals,
    required this.medications,
    required this.feelings,
    required this.storage,
    required this.isToday,
    required this.onReload,
  });

  @override
  State<_DateSection> createState() => _DateSectionState();
}

class _DateSectionState extends State<_DateSection> {
  ({int cal, double prot, double carbs, double fat})? _totals;
  bool _totalsLoaded = false;

  Future<void> _loadTotals() async {
    if (_totalsLoaded) return;
    final ids = widget.meals.where((m) => m.id != null).map((m) => m.id!).toList();
    final t = await widget.storage.getMacroTotalsForMeals(ids);
    if (!mounted) return;
    setState(() {
      _totals = t;
      _totalsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = widget.isToday
        ? 'Today · ${DateFormat('MMM d').format(widget.date)}'
        : DateFormat('EEEE, MMMM d').format(widget.date);

    final mealCount = widget.meals.length;
    final medCount = widget.medications.length;
    final feelingCount = widget.feelings.length;
    final parts = [
      if (mealCount > 0) '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
      if (medCount > 0) '$medCount ${medCount == 1 ? 'medication' : 'medications'}',
      if (feelingCount > 0) '$feelingCount ${feelingCount == 1 ? 'check-in' : 'check-ins'}',
    ];
    final subtitle = parts.isEmpty ? 'No entries' : parts.join(' · ');

    return Semantics(
      identifier: 'date-section-${widget.date.toIso8601String().substring(0, 10)}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(18), offset: const Offset(0, 1), blurRadius: 2),
            BoxShadow(color: Colors.black.withAlpha(38), offset: const Offset(0, 5), blurRadius: 10),
            BoxShadow(color: Colors.black.withAlpha(60), offset: const Offset(0, 12), blurRadius: 20),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (expanded) {
            if (expanded && widget.meals.isNotEmpty) _loadTotals();
          },
          title: Text(dateStr,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          children: [
            if (_totals != null && widget.meals.isNotEmpty)
              _MacroTotalsBar(totals: _totals!, theme: theme),
            ...widget.meals.map((m) => _MealTile(meal: m, storage: widget.storage, onReload: widget.onReload)),
            ...widget.medications.map((m) => _MedicationTile(med: m, onReload: widget.onReload)),
            ...widget.feelings.map((f) => _FeelingTile(log: f, onReload: widget.onReload)),
          ],
        ),
      ),
    );
  }
}

// ── Macro totals bar ──────────────────────────────────────────────────────────

class _MacroTotalsBar extends StatelessWidget {
  final ({int cal, double prot, double carbs, double fat}) totals;
  final ThemeData theme;

  const _MacroTotalsBar({required this.totals, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (totals.cal == 0 && totals.prot == 0 && totals.carbs == 0 && totals.fat == 0) {
      return const SizedBox.shrink();
    }
    final primary = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: primary,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: primary.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 12, color: primary),
              const SizedBox(width: 4),
              Text('DAY TOTALS', style: headerStyle),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (totals.cal > 0) _TotalCell(label: 'CAL', value: '${totals.cal}', labelStyle: labelStyle, theme: theme),
              if (totals.prot > 0) _TotalCell(label: 'PROT', value: '${totals.prot.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (totals.carbs > 0) _TotalCell(label: 'CARBS', value: '${totals.carbs.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (totals.fat > 0) _TotalCell(label: 'FAT', value: '${totals.fat.toInt()}g', labelStyle: labelStyle, theme: theme),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;

  const _TotalCell({required this.label, required this.value, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Meal tile ────────────────────────────────────────────────────────────────

class _MealTile extends StatefulWidget {
  final MealEntry meal;
  final StorageService storage;
  final VoidCallback onReload;

  const _MealTile({required this.meal, required this.storage, required this.onReload});

  @override
  State<_MealTile> createState() => _MealTileState();
}

class _MealTileState extends State<_MealTile> {
  final _tileKey = GlobalKey();
  bool _loaded = false;
  bool _loadingItems = false;
  List<_ItemWithIngredients> _items = [];

  Future<void> _loadItems() async {
    if (_loaded || _loadingItems) return;
    setState(() => _loadingItems = true);
    try {
      final foodItems = await widget.storage.getFoodItemsForMeal(widget.meal.id!);
      final withIngredients = await Future.wait(
        foodItems.map((item) async {
          final ings = item.id != null
              ? await widget.storage.getIngredientsForFoodItem(item.id!)
              : <Ingredient>[];
          return _ItemWithIngredients(item, ings);
        }),
      );
      if (!mounted) return;
      setState(() {
        _items = withIngredients;
        _loaded = true;
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = widget.meal;

    return Semantics(
      key: _tileKey,
      identifier: 'meal-tile-${meal.id}',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _loadItems();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_tileKey.currentContext != null) {
                Scrollable.ensureVisible(
                  _tileKey.currentContext!,
                  alignment: 0.1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
        },
        leading: meal.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(meal.imageData!, width: 40, height: 40, fit: BoxFit.cover),
              )
            : const Icon(Icons.restaurant_outlined),
        title: Semantics(
          identifier: 'meal-tile-header-${meal.id}',
          child: Text(meal.mealType,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        subtitle: Text(meal.time, style: theme.textTheme.bodySmall),
        children: [
          if (_loadingItems)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else ...[
            if (meal.imageData != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: Image.memory(meal.imageData!, width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._items.map((i) => FoodItemCard(item: i.item, ingredients: i.ingredients)),
                  if (meal.overallSymptoms != null && meal.overallSymptoms!.isNotEmpty)
                    _SymptomsRow(symptoms: meal.overallSymptoms!),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      identifier: 'btn-edit-meal-${meal.id}',
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/edit_meal', arguments: meal);
                          widget.onReload();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Medication tile ───────────────────────────────────────────────────────────

class _MedicationTile extends StatelessWidget {
  final Medication med;
  final VoidCallback onReload;

  const _MedicationTile({required this.med, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doseStr = [
      if (med.dose != null)
        med.dose! == med.dose!.truncateToDouble()
            ? med.dose!.toInt().toString()
            : med.dose!.toStringAsFixed(1),
      if (med.unit != null) med.unit!,
    ].join(' ');
    final subtitle = [
      med.time,
      if (doseStr.isNotEmpty) doseStr,
      if (med.route != null) med.route!,
    ].join(' · ');

    return Semantics(
      identifier: 'med-tile-${med.id}',
      child: ListTile(
        tileColor: theme.colorScheme.surfaceContainerHighest,
        leading: med.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(med.imageData!, width: 40, height: 40, fit: BoxFit.cover),
              )
            : const Icon(Icons.medication_outlined),
        title: Text(med.name,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-med-${med.id}',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () async {
              await Navigator.pushNamed(context, '/edit_medication', arguments: med);
              onReload();
            },
          ),
        ),
      ),
    );
  }
}

// ── Feeling tile ─────────────────────────────────────────────────────────────

class _FeelingTile extends StatelessWidget {
  final ReactionLog log;
  final VoidCallback onReload;

  const _FeelingTile({required this.log, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = TimeOfDay.fromDateTime(log.checkinTime).format(context);
    final severityLabel = log.severity == ReactionLevel.none ? 'No reaction' : log.severity.label;
    final symptomStr = log.symptoms.isEmpty ? '' : log.symptoms.join(', ');
    final subtitle = [timeStr, severityLabel, if (symptomStr.isNotEmpty) symptomStr].join(' · ');

    return Semantics(
      identifier: 'feeling-tile-${log.id}',
      child: ListTile(
        tileColor: theme.colorScheme.surfaceContainerHighest,
        leading: Icon(
          Icons.sentiment_satisfied_alt_outlined,
          color: theme.colorScheme.tertiary,
        ),
        title: Text(
          'How I felt',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-feeling-${log.id}',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () async {
              await Navigator.pushNamed(context, '/edit_checkin', arguments: log);
              onReload();
            },
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ItemWithIngredients {
  final FoodItem item;
  final List<Ingredient> ingredients;
  const _ItemWithIngredients(this.item, this.ingredients);
}

class _SymptomsRow extends StatelessWidget {
  final String symptoms;
  const _SymptomsRow({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: accent.withAlpha(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'After-meal: $symptoms',
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
