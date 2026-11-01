import 'package:flutter/services.dart';

/// A local notification request. Either one-shot ([at]) or repeating at a
/// clock time ([hour]/[minute], optionally on one [weekday] — DateTime
/// constants, 1 = Monday … 7 = Sunday).
class LocalNotification {
  const LocalNotification.once({required this.id, required this.title, required this.body, required DateTime this.at})
      : hour = null,
        minute = null,
        weekday = null;

  const LocalNotification.repeating({
    required this.id,
    required this.title,
    required this.body,
    required int this.hour,
    required int this.minute,
    this.weekday,
  }) : at = null;

  final String id;
  final String title;
  final String body;
  final DateTime? at;
  final int? hour;
  final int? minute;
  final int? weekday;

  bool get isRepeating => at == null;

  /// Apple numbers weekdays 1 = Sunday … 7 = Saturday.
  static int appleWeekday(int dartWeekday) => dartWeekday % 7 + 1;

  Map<String, Object?> toMap() => isRepeating
      ? {
          'id': id,
          'title': title,
          'body': body,
          'type': 'repeat',
          'hour': hour,
          'minute': minute,
          if (weekday != null) 'weekday': appleWeekday(weekday!),
        }
      : {
          'id': id,
          'title': title,
          'body': body,
          'type': 'date',
          'at': at!.millisecondsSinceEpoch,
        };
}

class DeviceCalendar {
  const DeviceCalendar({required this.id, required this.title, required this.color, required this.source});
  final String id;
  final String title;
  final String color;
  final String source;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarId,
  });
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String calendarId;
}

/// What the user chose to block. Apple keeps the actual apps as private
/// tokens on the device; the app only ever sees these counts.
class BlockSelection {
  const BlockSelection({this.apps = 0, this.categories = 0, this.sites = 0});

  final int apps;
  final int categories;
  final int sites;

  bool get isEmpty => apps + categories + sites == 0;

  static BlockSelection? fromMap(Object? raw) {
    if (raw is! Map) return null;
    int n(Object? v) => v is num ? v.toInt() : 0;
    return BlockSelection(apps: n(raw['apps']), categories: n(raw['categories']), sites: n(raw['sites']));
  }
}

/// Permission states reported by iOS.
enum PermissionState { unknown, notDetermined, authorized, denied, restricted, unsupported }

PermissionState _permission(Object? raw) => switch (raw) {
      'authorized' => PermissionState.authorized,
      'notDetermined' => PermissionState.notDetermined,
      'denied' || 'writeOnly' => PermissionState.denied,
      'restricted' => PermissionState.restricted,
      'unsupported' => PermissionState.unsupported,
      _ => PermissionState.unknown,
    };

/// Everything the app needs from iOS. [MethodChannelNative] talks to the
/// local `focus_native` plugin; tests and unsupported platforms get safe
/// defaults because missing plugins are caught.
abstract interface class NativePlatform {
  Future<String?> timeZone();
  Future<bool> openSettings();
  Future<PermissionState> notificationStatus();
  Future<bool> requestNotifications();
  Future<void> replaceNotifications(String prefix, List<LocalNotification> items);
  Future<void> addNotifications(List<LocalNotification> items);
  Future<void> cancelNotifications(List<String> ids);
  Future<PermissionState> calendarStatus();
  Future<bool> requestCalendar();
  Future<List<DeviceCalendar>> calendars();
  Future<List<CalendarEvent>> events(DateTime from, DateTime to, {List<String>? calendarIds});

  // App blocking (Screen Time API, iOS 16+).
  Future<PermissionState> blockingStatus();
  Future<bool> requestBlocking();

  /// Opens Apple's app picker. Null when cancelled.
  Future<BlockSelection?> pickBlockedApps({required String done, required String cancel});
  Future<BlockSelection> blockedCounts();
  Future<bool> startShield();
  Future<bool> stopShield();
}

class MethodChannelNative implements NativePlatform {
  const MethodChannelNative();

  static const _channel = MethodChannel('focus_reset/native');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<String?> timeZone() => _call<String>('getTimeZone');

  @override
  Future<bool> openSettings() async => await _call<bool>('openSettings') ?? false;

  @override
  Future<PermissionState> notificationStatus() async => _permission(await _call<String>('notificationStatus'));

  @override
  Future<bool> requestNotifications() async => await _call<bool>('requestNotifications') ?? false;

  @override
  Future<void> replaceNotifications(String prefix, List<LocalNotification> items) =>
      _call<int>('replaceNotifications', {'prefix': prefix, 'items': [for (final i in items) i.toMap()]});

  @override
  Future<void> addNotifications(List<LocalNotification> items) =>
      _call<int>('addNotifications', {'items': [for (final i in items) i.toMap()]});

  @override
  Future<void> cancelNotifications(List<String> ids) => _call<bool>('cancelNotifications', {'ids': ids});

  @override
  Future<PermissionState> calendarStatus() async => _permission(await _call<String>('calendarStatus'));

  @override
  Future<bool> requestCalendar() async => await _call<bool>('requestCalendar') ?? false;

  @override
  Future<List<DeviceCalendar>> calendars() async {
    final raw = await _call<List<Object?>>('calendars') ?? const [];
    return [
      for (final r in raw)
        if (r is Map)
          DeviceCalendar(
            id: '${r['id']}',
            title: '${r['title'] ?? ''}',
            color: '${r['color'] ?? '#8E8E93'}',
            source: '${r['source'] ?? ''}',
          ),
    ];
  }

  @override
  Future<PermissionState> blockingStatus() async {
    final raw = await _call<String>('blockingStatus');
    return raw == null ? PermissionState.unsupported : _permission(raw);
  }

  @override
  Future<bool> requestBlocking() async => await _call<bool>('requestBlocking') ?? false;

  @override
  Future<BlockSelection?> pickBlockedApps({required String done, required String cancel}) async =>
      BlockSelection.fromMap(await _call<Object>('pickBlockedApps', {'done': done, 'cancel': cancel}));

  @override
  Future<BlockSelection> blockedCounts() async =>
      BlockSelection.fromMap(await _call<Object>('blockedCounts')) ?? const BlockSelection();

  @override
  Future<bool> startShield() async => await _call<bool>('startShield') ?? false;

  @override
  Future<bool> stopShield() async => await _call<bool>('stopShield') ?? false;

  @override
  Future<List<CalendarEvent>> events(DateTime from, DateTime to, {List<String>? calendarIds}) async {
    final raw = await _call<List<Object?>>('events', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
          if (calendarIds != null && calendarIds.isNotEmpty) 'calendarIds': calendarIds,
        }) ??
        const [];
    final out = <CalendarEvent>[];
    for (final r in raw) {
      if (r is! Map) continue;
      final s = r['start'];
      final e = r['end'];
      if (s is! num || e is! num) continue;
      out.add(CalendarEvent(
        id: '${r['id']}',
        title: '${r['title'] ?? ''}',
        start: DateTime.fromMillisecondsSinceEpoch(s.round()),
        end: DateTime.fromMillisecondsSinceEpoch(e.round()),
        allDay: r['allDay'] == true,
        calendarId: '${r['calendarId'] ?? ''}',
      ));
    }
    return out;
  }
}
