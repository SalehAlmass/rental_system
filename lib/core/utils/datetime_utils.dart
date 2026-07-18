import 'package:intl/intl.dart';

class DateTimeUtils {
  static final _dateFormat12 = DateFormat('yyyy/MM/dd - hh:mm a');
  static final _timeFormat12 = DateFormat('hh:mm a');

  /// Parses date/time string from JSON which can be standard 24h format (Y-m-d H:i:s)
  /// or 12h format (Y-m-d h:i A or Y/m/d - h:i a).
  static DateTime? parse(dynamic input) {
    if (input == null) return null;
    final str = input.toString().trim();
    if (str.isEmpty) return null;

    // Try standard ISO / 24-hour formats
    var parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    
    parsed = DateTime.tryParse(str.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;

    try {
      // Clean up slashes
      final clean = str.replaceAll('/', '-').trim();
      
      // Parse 12-hour datetime (e.g. "2026-07-11 - 06:30 PM" or "2026-07-11 06:30 PM")
      final normalized = clean.replaceAll(RegExp(r'\s+-\s+'), ' '); // replace " - " with " " (at least one space each side to avoid breaking YYYY-MM-DD)
      final parts = normalized.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        // parts[0] is date (e.g. "2026-07-11")
        // parts[1] is time (e.g. "06:30:00" or "06:30")
        // parts[2] is AM/PM (e.g. "PM")
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          var hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
          
          final isPm = parts[2].toUpperCase().contains('P') || parts[2].contains('م');
          if (isPm && hour < 12) {
            hour += 12;
          } else if (!isPm && hour == 12) {
            hour = 0;
          }
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Formats DateTime to standard 12h display: YYYY/MM/DD - hh:mm AM/PM
  static String format(DateTime? dt) {
    if (dt == null) return '';
    return _dateFormat12.format(dt.toLocal());
  }

  /// Formats DateTime to time-only 12h display: hh:mm AM/PM
  static String formatTime(DateTime? dt) {
    if (dt == null) return '';
    return _timeFormat12.format(dt.toLocal());
  }

  /// Formats dynamic date string directly to 12h display format
  static String formatString(dynamic input) {
    if (input == null) return '';
    final dt = parse(input);
    return format(dt);
  }
}
