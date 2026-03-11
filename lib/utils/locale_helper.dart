import 'package:flutter/material.dart';

class LocaleHelper {
  static const Locale enLocale = Locale('en', '');
  static const Locale arLocale = Locale('ar', '');

  static Locale getLocale(String languageCode) {
    if (languageCode == 'ar') {
      return arLocale;
    }
    return enLocale;
  }
}
