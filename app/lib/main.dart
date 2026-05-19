import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/meal_entry.dart';
import 'models/medication.dart';
import 'models/reaction_log.dart';
import 'models/weight_log.dart';
import 'screens/checkin/checkin_screen.dart';
import 'screens/export/export_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/log_meal/log_meal_screen.dart';
import 'screens/log_medication/log_medication_screen.dart';
import 'screens/log_weight/log_weight_screen.dart';
import 'screens/meal_detail/meal_detail_screen.dart';
import 'services/notification_service.dart';
import 'services/seed_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final storage = StorageService();
  if (kDebugMode && !await storage.hasMeals()) {
    await SeedService().seed(storage);
  }
  storage.dispose();

  await NotificationService().initialize();
  runApp(const FoodJournalApp());
}

class FoodJournalApp extends StatelessWidget {
  const FoodJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF42725C)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/log': (_) => const LogMealScreen(),
        '/log_medication': (_) => const LogMedicationScreen(),
        '/log_weight': (_) => const LogWeightScreen(),
        '/export': (_) => const ExportScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/meal') {
          final mealId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => MealDetailScreen(mealId: mealId),
          );
        }
        if (settings.name == '/checkin') {
          final mealId = settings.arguments as int?;
          return MaterialPageRoute(
            builder: (_) => CheckinScreen(mealId: mealId),
          );
        }
        if (settings.name == '/edit_meal') {
          final meal = settings.arguments as MealEntry;
          return MaterialPageRoute(
            builder: (_) => LogMealScreen(existingMeal: meal),
          );
        }
        if (settings.name == '/edit_medication') {
          final med = settings.arguments as Medication;
          return MaterialPageRoute(
            builder: (_) => LogMedicationScreen(existingMed: med),
          );
        }
        if (settings.name == '/edit_checkin') {
          final log = settings.arguments as ReactionLog;
          return MaterialPageRoute(
            builder: (_) => CheckinScreen(existingLog: log),
          );
        }
        if (settings.name == '/edit_weight') {
          final log = settings.arguments as WeightLog;
          return MaterialPageRoute(
            builder: (_) => LogWeightScreen(existingLog: log),
          );
        }
        return null;
      },
    );
  }
}
