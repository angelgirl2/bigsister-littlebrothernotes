class PersianDate {
  static const List<int> _gDaysInMonth = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  static ({int year, int month, int day}) fromGregorian(DateTime input) {
    var gy = input.year;
    final gm = input.month;
    final gd = input.day;
    gy -= gm <= 2 ? 1 : 0;

    var days = 365 * gy + ((gy + 3) ~/ 4) - ((gy + 99) ~/ 100) + ((gy + 399) ~/ 400);
    for (var i = 0; i < gm - 1; i++) {
      days += _gDaysInMonth[i];
    }
    if (gm > 2 && ((input.year % 4 == 0 && input.year % 100 != 0) || input.year % 400 == 0)) {
      days += 1;
    }
    days += gd - 1;

    var jy = -1595 + 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
    return (year: jy, month: jm, day: jd);
  }

  static String digits(String value) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var out = value;
    for (var i = 0; i < en.length; i++) {
      out = out.replaceAll(en[i], fa[i]);
    }
    return out;
  }

  static String date(DateTime value) {
    final local = value.toLocal();
    final j = fromGregorian(local);
    return digits('${j.year.toString().padLeft(4, '0')}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');
  }

  static String time(DateTime value) {
    final local = value.toLocal();
    return digits('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}');
  }
}
