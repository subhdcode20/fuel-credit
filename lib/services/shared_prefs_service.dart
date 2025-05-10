import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _firstTimeKey = 'is_first_time';

  // Check if it's the first time opening the app
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  // Set that the app has been opened before
  static Future<void> setNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, false);
  }
}