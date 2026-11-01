import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/l10n/app_strings.dart';
import '../data/models/planning_models.dart';
import '../data/services/native_bridge.dart';
import '../data/services/preferences_service.dart';
import '../domain/notifications/notification_planner.dart';
import 'app_controller.dart';
import 'planner_controller.dart';

/// iOS integrations: local reminders, read-only Apple Calendar and the
/// device time zone. Every permission is requested only when the user turns
/// the feature on, through the standard iOS prompt.
class IntegrationsController extends ChangeNotifier with WidgetsBindingObserver {
  IntegrationsController({
    required AppController app,
    required PlannerController planner,
    required KeyValueStore store,
    NativePlatform native = const MethodChannelNative(),
  })  : _app = app,
        _planner = planner,
        _store = store,
        _native = native;

  final AppController _app;
  final PlannerController _planner;
  final KeyValueStore _store;
  final NativePlatform _native;

  static const _kNotif = 'settings.notifications.v1';
  static const _kCalendar = 'settings.calendar.v1';
  static const _kBlocking = 'settings.blocking.v1';
  static const focusNotificationId = 'frx.focus';

  NotificationPrefs _prefs = const NotificationPrefs();
  PermissionState _notifPermission = PermissionState.unknown;
  bool _calendarEnabled = false;
  Set<String> _calendarIds = {};
  PermissionState _calendarPermission = PermissionState.unknown;
  List<DeviceCalendar> _calendars = const [];
  int _pending = 0;
  String? _timeZone;
  bool _blockingEnabled = false;
  PermissionState _blockingPermission = PermissionState.unknown;
  bool _blockingUnavailable = false;
  BlockSelection _blocked = const BlockSelection();
  DateTime? _shieldUntil;
  Timer? _debounce;
  bool _started = false;

  NotificationPrefs get notificationPrefs => _prefs;
  PermissionState get notificationPermission => _notifPermission;
  bool get calendarEnabled => _calendarEnabled;
  Set<String> get selectedCalendarIds => _calendarIds;
  PermissionState get calendarPermission => _calendarPermission;
  List<DeviceCalendar> get calendars => _calendars;
  int get pendingReminders => _pending;
  String? get timeZone => _timeZone;

  bool get blockingEnabled => _blockingEnabled;
  PermissionState get blockingPermission => _blockingPermission;

  /// Authorization failed without a decision from the user — the build does
  /// not have Apple's Family Controls entitlement yet.
  bool get blockingUnavailable => _blockingUnavailable;
  BlockSelection get blockedSelection => _blocked;
  bool get shieldActive => _shieldUntil != null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _load();
    WidgetsBinding.instance.addObserver(this);
    _planner.addListener(_schedule);
    _app.addListener(_schedule);
    await _refreshAll();
  }

  void _load() {
    try {
      final n = _store.getString(_kNotif);
      if (n != null) _prefs = NotificationPrefs.fromJson(jsonDecode(n) as Map<String, dynamic>);
      final c = _store.getString(_kCalendar);
      if (c != null) {
        final j = jsonDecode(c) as Map<String, dynamic>;
        _calendarEnabled = j['enabled'] == true;
        _calendarIds = ((j['ids'] as List?) ?? const []).map((e) => '$e').toSet();
      }
      final b = _store.getString(_kBlocking);
      if (b != null) {
        final j = jsonDecode(b) as Map<String, dynamic>;
        _blockingEnabled = j['enabled'] == true;
        final until = j['until'];
        _shieldUntil = until is String ? DateTime.tryParse(until)?.toLocal() : null;
      }
    } catch (_) {
      // Corrupt settings: fall back to defaults.
    }
  }

  Future<void> _saveCalendarPrefs() =>
      _store.setString(_kCalendar, jsonEncode({'enabled': _calendarEnabled, 'ids': _calendarIds.toList()}));

  Future<void> _saveBlocking() => _store.setString(
        _kBlocking,
        jsonEncode({'enabled': _blockingEnabled, 'until': _shieldUntil?.toUtc().toIso8601String()}),
      );

  Future<void> _refreshAll() async {
    _notifPermission = await _native.notificationStatus();
    _calendarPermission = await _native.calendarStatus();
    _blockingPermission = await _native.blockingStatus();
    _blocked = await _native.blockedCounts();
    await _expireShield();
    await _syncTimeZone();
    await refreshCalendar();
    await rescheduleNotifications();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  // ------------------------------------------------------------ time zone

  Future<void> _syncTimeZone() async {
    _timeZone = await _native.timeZone();
    final tz = _timeZone;
    final p = _app.profile;
    // Record the real IANA zone as "home" once (it was a short abbreviation
    // before); later changes while travelling don't overwrite home.
    if (tz != null && tz.contains('/') && p != null && !p.homeTimeZone.contains('/')) {
      await _app.saveProfile(p.copyWith(homeTimeZone: tz));
    }
  }

  // -------------------------------------------------------- notifications

  String _localeTag() {
    final l = _app.locale ??
        AppStrings.resolve(WidgetsBinding.instance.platformDispatcher.locale, AppStrings.supportedLocales);
    return l.languageCode;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), rescheduleNotifications);
  }

  Future<void> rescheduleNotifications() async {
    final strings = AppStrings(Locale(_localeTag()));
    final time = DateFormat.jm(_localeTag());
    final allowed = _notifPermission == PermissionState.authorized;
    final items = NotificationPlanner.build(
      prefs: allowed ? _prefs : _prefs.copyWith(enabled: false),
      profile: _app.profile,
      tasks: _planner.tasks,
      habits: _planner.habits,
      now: DateTime.now(),
      tr: strings.get,
      clock: time.format,
      unit: strings.get,
    );
    await _native.replaceNotifications(NotificationPlanner.prefix, items);
    if (_pending != items.length) {
      _pending = items.length;
      notifyListeners();
    }
  }

  /// Turning reminders on asks iOS for permission the first time.
  /// Returns false when iOS permission is denied.
  Future<bool> setNotificationsEnabled(bool on) async {
    if (on) {
      var state = await _native.notificationStatus();
      if (state == PermissionState.notDetermined) {
        await _native.requestNotifications();
        state = await _native.notificationStatus();
      }
      _notifPermission = state;
      if (state != PermissionState.authorized) {
        notifyListeners();
        return false;
      }
    }
    await updateNotificationPrefs(_prefs.copyWith(enabled: on));
    return true;
  }

  Future<void> updateNotificationPrefs(NotificationPrefs p) async {
    _prefs = p;
    notifyListeners();
    await _store.setString(_kNotif, jsonEncode(p.toJson()));
    await rescheduleNotifications();
  }

  Future<void> openSystemSettings() => _native.openSettings();

  /// Alert when a running focus/break timer ends while the app is closed.
  Future<void> scheduleTimerEnd(DateTime at, {required bool focus}) async {
    if (!_prefs.enabled || _notifPermission != PermissionState.authorized) return;
    final strings = AppStrings(Locale(_localeTag()));
    await _native.cancelNotifications(const [focusNotificationId]);
    await _native.addNotifications([
      LocalNotification.once(
        id: focusNotificationId,
        title: strings.get(focus ? 'notif.focusDoneTitle' : 'notif.breakDoneTitle'),
        body: strings.get(focus ? 'notif.focusDoneBody' : 'notif.breakDoneBody'),
        at: at,
      ),
    ]);
  }

  Future<void> cancelTimerEnd() => _native.cancelNotifications(const [focusNotificationId]);

  // --------------------------------------------------------- app blocking

  /// Lifts a shield whose focus session already ended (e.g. the app was
  /// closed during the session).
  Future<void> _expireShield() async {
    final until = _shieldUntil;
    if (until != null && !DateTime.now().isBefore(until)) await stopFocusShield();
  }

  /// Returns false when blocking cannot be turned on (unsupported iOS
  /// version, permission refused, or entitlement not approved yet).
  Future<bool> setBlockingEnabled(bool on) async {
    if (on) {
      if (_blockingPermission == PermissionState.unsupported) return false;
      if (_blockingPermission != PermissionState.authorized) {
        final ok = await _native.requestBlocking();
        _blockingPermission = await _native.blockingStatus();
        if (_blockingPermission != PermissionState.authorized) {
          _blockingUnavailable = !ok && _blockingPermission != PermissionState.denied;
          notifyListeners();
          return false;
        }
      }
      _blockingUnavailable = false;
    } else {
      await stopFocusShield();
    }
    _blockingEnabled = on;
    await _saveBlocking();
    notifyListeners();
    return true;
  }

  Future<void> pickBlockedApps({required String done, required String cancel}) async {
    final picked = await _native.pickBlockedApps(done: done, cancel: cancel);
    if (picked != null) {
      _blocked = picked;
      notifyListeners();
    }
  }

  /// Shields the chosen apps until [until] (the end of the focus session).
  Future<void> startFocusShield(DateTime until) async {
    if (!_blockingEnabled || _blockingPermission != PermissionState.authorized || _blocked.isEmpty) return;
    if (await _native.startShield()) {
      _shieldUntil = until;
      await _saveBlocking();
      notifyListeners();
    }
  }

  Future<void> stopFocusShield() async {
    if (_shieldUntil == null) return;
    await _native.stopShield();
    _shieldUntil = null;
    await _saveBlocking();
    notifyListeners();
  }

  // ------------------------------------------------------------- calendar

  /// Returns false when iOS calendar access was not granted.
  Future<bool> setCalendarEnabled(bool on) async {
    if (on) {
      var state = await _native.calendarStatus();
      if (state == PermissionState.notDetermined) {
        await _native.requestCalendar();
        state = await _native.calendarStatus();
      }
      _calendarPermission = state;
      if (state != PermissionState.authorized) {
        notifyListeners();
        return false;
      }
    }
    _calendarEnabled = on;
    await _saveCalendarPrefs();
    await refreshCalendar();
    notifyListeners();
    return true;
  }

  Future<void> toggleCalendar(String id) async {
    // An empty selection means "all calendars"; the first tap narrows it.
    final all = _calendars.map((c) => c.id).toSet();
    final current = _calendarIds.isEmpty ? all : {..._calendarIds};
    if (!current.remove(id)) current.add(id);
    _calendarIds = current.length == all.length ? {} : current;
    await _saveCalendarPrefs();
    await refreshCalendar();
    notifyListeners();
  }

  bool isCalendarSelected(String id) => _calendarIds.isEmpty || _calendarIds.contains(id);

  Future<void> refreshCalendar() async {
    if (!_calendarEnabled || _calendarPermission != PermissionState.authorized) {
      _calendars = const [];
      _planner.setExternalCommitments(const []);
      return;
    }
    _calendars = await _native.calendars();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - 1);
    final to = DateTime(now.year, now.month, now.day + 15);
    final events = await _native.events(from, to, calendarIds: _calendarIds.isEmpty ? null : _calendarIds.toList());
    _planner.setExternalCommitments([
      for (final e in events)
        if (!e.allDay && e.end.isAfter(e.start))
          Commitment(
            id: 'cal:${e.id}:${e.start.millisecondsSinceEpoch}',
            type: CommitmentType.appointment,
            title: e.title,
            start: e.start,
            end: e.end,
          ),
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _planner.removeListener(_schedule);
      _app.removeListener(_schedule);
    }
    super.dispose();
  }
}

class IntegrationsScope extends InheritedNotifier<IntegrationsController> {
  const IntegrationsScope({super.key, required IntegrationsController controller, required super.child})
      : super(notifier: controller);

  static IntegrationsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IntegrationsScope>()!.notifier!;

  static IntegrationsController read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<IntegrationsScope>()!.widget as IntegrationsScope).notifier!;
}
