import 'package:intl/intl.dart';

/// Pure display formatting helpers.
abstract class Formatters {
  Formatters._();

  /// `124` → `2 hrs 4 mins`.
  static String runtime(num minutes) {
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    final hPart = h == 0 ? '' : '$h ${h == 1 ? 'hr' : 'hrs'}';
    final mPart = m == 0 ? '' : '$m ${m == 1 ? 'min' : 'mins'}';
    return [hPart, mPart].where((p) => p.isNotEmpty).join(' ');
  }

  /// `Oct 8th • 8:00 PM` in the device's local time.
  static String premiereDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day;
    return '${DateFormat('MMM').format(local)} $day${_ordinal(day)} • '
        '${DateFormat('h:mm a').format(local)}';
  }

  /// Playback clock: `51:17` or `2:04:00`.
  static String clock(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// `41h 12m` for the "doors close" row.
  static String hoursMinutes(Duration d) {
    final total = d.inMinutes < 0 ? 0 : d.inMinutes;
    return '${total ~/ 60}h ${total % 60}m';
  }

  /// `₦5,000`.
  static String naira(num amount) =>
      '₦${NumberFormat.decimalPattern().format(amount)}';

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
