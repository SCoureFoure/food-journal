import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAiEnabled = 'ai_enabled';

  Future<bool> get isAiEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAiEnabled) ?? true;
  }

  Future<void> setAiEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiEnabled, value);
  }
}
