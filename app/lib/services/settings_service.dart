import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAiEnabled = 'ai_enabled';
  static const _keyLeftHanded = 'left_handed';

  Future<bool> get isAiEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAiEnabled) ?? true;
  }

  Future<void> setAiEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiEnabled, value);
  }

  Future<bool> get isLeftHanded async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLeftHanded) ?? false;
  }

  Future<void> setLeftHanded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLeftHanded, value);
  }

  /// Whether a Meal Planning card ([card] is `pantry` or `grocery`) is collapsed.
  /// Cards start expanded.
  Future<bool> isCardCollapsed(String card) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('card_collapsed_$card') ?? false;
  }

  Future<void> setCardCollapsed(String card, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('card_collapsed_$card', value);
  }

  static const _keyGroceryDraft = 'grocery_draft';

  /// The saved grocery list the user is working on. Not a preference — it lives
  /// here because this is the app's only SharedPreferences wrapper. Empty string
  /// means "no list yet".
  Future<String> get groceryDraft async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGroceryDraft) ?? '';
  }

  Future<void> setGroceryDraft(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroceryDraft, value);
  }

  Future<void> clearGroceryDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGroceryDraft);
  }
}
