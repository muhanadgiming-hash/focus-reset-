import 'package:flutter_test/flutter_test.dart';
import 'package:focus_reset/app/app_controller.dart';
import 'package:focus_reset/app/integrations_controller.dart';
import 'package:focus_reset/app/planner_controller.dart';
import 'package:focus_reset/data/repositories/planner_repository.dart';
import 'package:focus_reset/data/repositories/profile_repository.dart';
import 'package:focus_reset/data/services/native_bridge.dart';
import 'package:focus_reset/data/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simulates iOS. [entitled] mirrors whether the build has Apple's
/// Family Controls entitlement.
class FakeNative implements NativePlatform {
  FakeNative({this.entitled = true});

  final bool entitled;
  PermissionState blocking = PermissionState.notDetermined;
  BlockSelection selection = const BlockSelection();
  bool shielded = false;

  @override
  Future<PermissionState> blockingStatus() async => blocking;

  @override
  Future<bool> requestBlocking() async {
    if (!entitled) return false; // authorization throws without the entitlement
    blocking = PermissionState.authorized;
    return true;
  }

  @override
  Future<BlockSelection?> pickBlockedApps({required String done, required String cancel}) async {
    selection = const BlockSelection(apps: 3, categories: 1);
    return selection;
  }

  @override
  Future<BlockSelection> blockedCounts() async => selection;

  @override
  Future<bool> startShield() async {
    if (selection.isEmpty) return false;
    shielded = true;
    return true;
  }

  @override
  Future<bool> stopShield() async {
    shielded = false;
    return true;
  }

  // Not used by these tests.
  @override
  Future<String?> timeZone() async => 'Asia/Riyadh';
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<PermissionState> notificationStatus() async => PermissionState.notDetermined;
  @override
  Future<bool> requestNotifications() async => false;
  @override
  Future<void> replaceNotifications(String prefix, List<LocalNotification> items) async {}
  @override
  Future<void> addNotifications(List<LocalNotification> items) async {}
  @override
  Future<void> cancelNotifications(List<String> ids) async {}
  @override
  Future<PermissionState> calendarStatus() async => PermissionState.notDetermined;
  @override
  Future<bool> requestCalendar() async => false;
  @override
  Future<List<DeviceCalendar>> calendars() async => const [];
  @override
  Future<List<CalendarEvent>> events(DateTime from, DateTime to, {List<String>? calendarIds}) async => const [];
}

Future<IntegrationsController> controller(FakeNative native) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PreferencesService.create();
  final app = AppController(prefs: prefs, profiles: LocalProfileRepository(prefs));
  final planner = PlannerController(repository: LocalPlannerRepository(prefs));
  return IntegrationsController(app: app, planner: planner, store: prefs, native: native);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without Apple approval, blocking reports unavailable and never claims to work', () async {
    final native = FakeNative(entitled: false);
    final ix = await controller(native);
    expect(await ix.setBlockingEnabled(true), isFalse);
    expect(ix.blockingEnabled, isFalse);
    expect(ix.blockingUnavailable, isTrue);
    await ix.startFocusShield(DateTime.now().add(const Duration(minutes: 25)));
    expect(native.shielded, isFalse);
  });

  test('with approval, chosen apps are shielded only during a session', () async {
    final native = FakeNative();
    final ix = await controller(native);
    expect(await ix.setBlockingEnabled(true), isTrue);

    // Nothing chosen yet: no shield.
    await ix.startFocusShield(DateTime.now().add(const Duration(minutes: 25)));
    expect(native.shielded, isFalse);

    await ix.pickBlockedApps(done: 'Done', cancel: 'Cancel');
    await ix.startFocusShield(DateTime.now().add(const Duration(minutes: 25)));
    expect(native.shielded, isTrue);
    expect(ix.shieldActive, isTrue);

    await ix.stopFocusShield();
    expect(native.shielded, isFalse);
    expect(ix.shieldActive, isFalse);
  });

  test('turning blocking off lifts an active shield', () async {
    final native = FakeNative();
    final ix = await controller(native);
    await ix.setBlockingEnabled(true);
    await ix.pickBlockedApps(done: 'Done', cancel: 'Cancel');
    await ix.startFocusShield(DateTime.now().add(const Duration(minutes: 25)));
    await ix.setBlockingEnabled(false);
    expect(native.shielded, isFalse);
  });
}
