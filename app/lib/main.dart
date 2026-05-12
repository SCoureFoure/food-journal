import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/checkin/checkin_screen.dart';
import 'screens/export/export_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/log_meal/log_meal_screen.dart';
import 'screens/meal_detail/meal_detail_screen.dart';
import 'services/notification_service.dart';
import 'services/seed_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final storage = StorageService();
  if (!await storage.hasMeals()) {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC4502A)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/log': (_) => const LogMealScreen(),
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
          final mealId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => CheckinScreen(mealId: mealId),
          );
        }
        return null;
      },
    );
  }
}
