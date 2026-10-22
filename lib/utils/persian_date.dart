import 'package:flutter/material.dart';

/// تبدیل تاریخ برای نمایش فارسی/شمسی؛ تاریخ‌های ذخیره‌شده در دیتابیس تغییر نمی‌کنند.
class PersianDate {
  static const List<int> _gDaysInMonth = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  static const List<String> months = <String>[
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  static ({int year, int month, int day}) fromGregorian(DateTime input) {
    // الگوریتم استاندارد تبدیل میلادی به جلالی (بدون وابستگی بیرونی).
    final gy = input.year - 1600;
    final gm = input.month - 1;
    final gd = input.day - 1;
    var days = 365 * gy + ((gy + 3) ~/ 4) - ((gy + 99) ~/ 100) + ((gy + 399) ~/ 400);
    for (var i = 0; i < gm; i++) { days += _gDaysInMonth[i]; }
    final leap = (input.year % 4 == 0 && input.year % 100 != 0) || input.year % 400 == 0;
    if (gm > 1 && leap) days++;
    days += gd;
    var jDays = days - 79;
    final cycles = jDays ~/ 12053;
    jDays %= 12053;
    var jy = 979 + 33 * cycles + 4 * (jDays ~/ 1461);
    jDays %= 1461;
    if (jDays > 365) { jy += (jDays - 1) ~/ 365; jDays = (jDays - 1) % 365; }
    final jm = jDays < 186 ? 1 + jDays ~/ 31 : 7 + (jDays - 186) ~/ 30;
    final jd = 1 + (jDays < 186 ? jDays % 31 : (jDays - 186) % 30);
    return (year: jy, month: jm, day: jd);
  }

  static DateTime toGregorian(int jy, int jm, int jd, {int hour = 0, int minute = 0, int second = 0}) {
    var y = jy + 1595;
    var days = -355668 + 365 * y + (y ~/ 33) * 8 + ((y % 33 + 3) ~/ 4) + jd;
    days += jm <= 6 ? (jm - 1) * 31 : 186 + (jm - 7) * 30;
    var gy = 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gy += 100 * ((--days) ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) { gy += (days - 1) ~/ 365; days = (days - 1) % 365; }
    var gd = days + 1;
    final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
    final lengths = List<int>.from(_gDaysInMonth)..[1] = leap ? 29 : 28;
    var gm = 1;
    while (gm <= 12 && gd > lengths[gm - 1]) { gd -= lengths[gm - 1]; gm++; }
    return DateTime(gy, gm, gd, hour, minute, second);
  }

  static int daysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    final start = toGregorian(year, 12, 1);
    final next = toGregorian(year + 1, 1, 1);
    return next.difference(start).inDays;
  }

  static String digits(String value) {
    const en = '0123456789'; const fa = '۰۱۲۳۴۵۶۷۸۹';
    var out = value;
    for (var i = 0; i < en.length; i++) { out = out.replaceAll(en[i], fa[i]); }
    return out;
  }

  static String date(DateTime value) {
    final j = fromGregorian(value.toLocal());
    return digits('${j.year.toString().padLeft(4, '0')}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');
  }

  static String dateTime(DateTime value) => '${date(value)} • ${time(value)}';
  static String monthYear(DateTime value) {
    final j = fromGregorian(value.toLocal());
    return '${months[j.month - 1]} ${digits(j.year.toString())}';
  }
  static String time(DateTime value) {
    final local = value.toLocal();
    return digits('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
  }
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final firstJ = fromGregorian(firstDate);
    final lastJ = fromGregorian(lastDate);
    final initialJ = fromGregorian(initialDate);
    var year = initialJ.year.clamp(firstJ.year, lastJ.year).toInt();
    var month = initialJ.month;
    var day = initialJ.day;
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final maxDay = daysInMonth(year, month);
          if (day > maxDay) day = maxDay;
          final years = List<int>.generate(lastJ.year - firstJ.year + 1, (i) => firstJ.year + i);
          return AlertDialog(
            title: const Text('انتخاب تاریخ شمسی'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'ماه'),
                    items: List<DropdownMenuItem<int>>.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                    onChanged: (v) { if (v != null) setState(() { month = v; if (day > daysInMonth(year, month)) day = daysInMonth(year, month); }); },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(labelText: 'سال'),
                    items: years.map((v) => DropdownMenuItem(value: v, child: Text(digits(v.toString())))).toList(),
                    onChanged: (v) { if (v != null) setState(() { year = v; if (day > daysInMonth(year, month)) day = daysInMonth(year, month); }); },
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: day.clamp(1, maxDay).toInt(),
                  decoration: const InputDecoration(labelText: 'روز'),
                  items: List<DropdownMenuItem<int>>.generate(maxDay, (i) => DropdownMenuItem(value: i + 1, child: Text(digits((i + 1).toString())))),
                  onChanged: (v) { if (v != null) setState(() => day = v); },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
              FilledButton(onPressed: () {
                final result = toGregorian(year, month, day);
                if (result.isBefore(DateTime(firstDate.year, firstDate.month, firstDate.day)) || result.isAfter(DateTime(lastDate.year, lastDate.month, lastDate.day))) return;
                Navigator.pop(dialogContext, result);
              }, child: const Text('تأیید')),
            ],
          );
        },
      ),
    );
  }

}
