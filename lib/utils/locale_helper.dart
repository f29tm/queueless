import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleHelper {
  static const String _languageKey = 'selected_language';

  static const Locale enLocale = Locale('en');
  static const Locale arLocale = Locale('ar');

  static Locale getLocale(String languageCode) {
    return languageCode == 'ar' ? arLocale : enLocale;
  }

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> loadLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  static bool isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}
