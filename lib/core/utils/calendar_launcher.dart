import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches the user's calendar with a pre-filled premiere event.
///
/// - For **upcoming premieres** (`premiereStart` is in the future), the event
///   is scheduled at `premiereStart`.
/// - For **movies already premiering** (`premiereStart <= now < premiereEnd`),
///   picks a convenient time inside the active premiere window (`now + 30 min`,
///   clamped so the event fits before `premiereEnd`).
class CalendarLauncher {
  const CalendarLauncher._();

  static const MethodChannel _nativeChannel =
      MethodChannel('premia/screen_protection');

  /// Computes the `(start, end)` window for a film's calendar reminder and
  /// opens the user's calendar app (or Google Calendar fallback) pre-populated
  /// with the movie name and screening time.
  static Future<bool> addPremiereToCalendar({
    required String title,
    String? description,
    DateTime? premiereStart,
    DateTime? premiereEnd,
    num? durationMinutes,
  }) async {
    final now = DateTime.now();
    final movieDuration = Duration(
      minutes: (durationMinutes != null && durationMinutes > 0)
          ? durationMinutes.round()
          : 120,
    );

    late final DateTime eventStart;
    if (premiereStart != null && premiereStart.isAfter(now)) {
      // Upcoming premiere -> schedule at exact premiere start time
      eventStart = premiereStart.toLocal();
    } else if (premiereEnd != null && premiereEnd.isAfter(now)) {
      // Movie is currently premiering -> schedule within the active premiere window
      final candidate = now.add(const Duration(minutes: 30));
      final latestStart = premiereEnd.toLocal().subtract(movieDuration);
      if (candidate.isBefore(premiereEnd.toLocal())) {
        if (latestStart.isAfter(now) && candidate.isAfter(latestStart)) {
          eventStart = latestStart;
        } else {
          eventStart = candidate;
        }
      } else {
        eventStart = now.add(const Duration(minutes: 5));
      }
    } else {
      eventStart = (premiereStart ?? now.add(const Duration(hours: 1))).toLocal();
    }

    DateTime eventEnd = eventStart.add(movieDuration);
    if (premiereEnd != null &&
        premiereEnd.toLocal().isAfter(eventStart) &&
        eventEnd.isAfter(premiereEnd.toLocal())) {
      eventEnd = premiereEnd.toLocal();
    }

    final eventTitle = 'Premia Premiere: $title';
    final eventDetails = (description != null && description.trim().isNotEmpty)
        ? '${description.trim()}\n\nWatch on Premia Digital Cinema.'
        : 'Watch "$title" on Premia Digital Cinema.';

    // 1. On Android, open the native system Calendar app's new-event screen directly
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final launched = await _nativeChannel.invokeMethod<bool>(
          'addCalendarEvent',
          {
            'title': eventTitle,
            'description': eventDetails,
            'location': 'Premia Digital Cinema',
            'beginTime': eventStart.millisecondsSinceEpoch,
            'endTime': eventEnd.millisecondsSinceEpoch,
          },
        );
        if (launched == true) return true;
      } catch (_) {
        // Fall through to Google Calendar URL if native intent fails
      }
    }

    // 2. Universal Google Calendar template URL (opens Google Calendar app or browser on iOS/Android)
    final gcalUri = Uri.https(
      'calendar.google.com',
      '/calendar/render',
      {
        'action': 'TEMPLATE',
        'text': eventTitle,
        'dates': '${_formatUtc(eventStart)}/${_formatUtc(eventEnd)}',
        'details': eventDetails,
        'location': 'Premia Digital Cinema',
      },
    );

    try {
      final ok = await launchUrl(
        gcalUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return true;
      return await launchUrl(gcalUri);
    } catch (_) {
      return false;
    }
  }

  static String _formatUtc(DateTime dt) {
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }
}
