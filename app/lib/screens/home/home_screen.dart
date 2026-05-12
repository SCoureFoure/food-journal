import 'package:flutter/material.dart';

import '../../models/meal_entry.dart';
import '../../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<MealEntry> _meals = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final meals = await _storage.getMealsForDay(DateTime.now());
      if (!mounted) return;
      setState(() {
        _meals = meals;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => Navigator.pushNamed(context, '/export'),
            tooltip: 'Export',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/log');
          _loadMeals();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadMeals,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_meals.isEmpty) {
      return const Center(child: Text('No meals logged yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _meals.length,
      itemBuilder: (_, i) => _MealCard(meal: _meals[i]),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealEntry meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(meal.mealType),
        subtitle: Text(meal.time),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, '/meal', arguments: meal.id),
      ),
    );
  }
}
