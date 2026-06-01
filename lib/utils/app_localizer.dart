import 'package:flutter/material.dart';

class AppLocalizer {
  static bool isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  static String text(BuildContext context, String en, String ar) {
    return isArabic(context) ? ar : en;
  }

  static TextDirection direction(BuildContext context) {
    return isArabic(context) ? TextDirection.rtl : TextDirection.ltr;
  }

  static String firestoreField({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String enKey,
    required String arKey,
    required String fallback,
  }) {
    if (isArabic(context)) {
      return (data[arKey] ?? data[enKey] ?? fallback).toString();
    }

    return (data[enKey] ?? fallback).toString();
  }

  static String date(BuildContext context, String value) {
    if (!isArabic(context)) return value;

    return value
        .replaceAll('Sat', 'السبت')
        .replaceAll('Sun', 'الأحد')
        .replaceAll('Mon', 'الاثنين')
        .replaceAll('Tue', 'الثلاثاء')
        .replaceAll('Wed', 'الأربعاء')
        .replaceAll('Thu', 'الخميس')
        .replaceAll('Fri', 'الجمعة')
        .replaceAll('Jan', 'يناير')
        .replaceAll('Feb', 'فبراير')
        .replaceAll('Mar', 'مارس')
        .replaceAll('Apr', 'أبريل')
        .replaceAll('May', 'مايو')
        .replaceAll('Jun', 'يونيو')
        .replaceAll('Jul', 'يوليو')
        .replaceAll('Aug', 'أغسطس')
        .replaceAll('Sep', 'سبتمبر')
        .replaceAll('Oct', 'أكتوبر')
        .replaceAll('Nov', 'نوفمبر')
        .replaceAll('Dec', 'ديسمبر');
  }

  static String time(BuildContext context, String value) {
    if (!isArabic(context)) return value;

    return value
        .replaceAll('AM', 'صباحاً')
        .replaceAll('PM', 'مساءً');
  }

  static String status(BuildContext context, String value) {
    if (!isArabic(context)) return value;

    switch (value.toLowerCase()) {
      case 'scheduled':
        return 'مجدول';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return value;
    }
  }

  static String reason(BuildContext context, String value) {
    if (!isArabic(context)) return value;

    switch (value.toLowerCase()) {
      case 'regular check up':
      case 'regular checkup':
        return 'فحص طبي دوري';
      case 'general consultation':
        return 'استشارة عامة';
      default:
        return value;
    }
  }
}