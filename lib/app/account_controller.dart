import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/services/auth_service.dart';
import '../data/sync/sync_engine.dart';
import 'app_controller.dart';
import 'planner_controller.dart';

enum SyncStatus {
  /// This build has no cloud configuration: everything stays on the device.
  localOnly,
  signedOut,
  idle,
  syncing,
  offline,
}

/// Account state and background synchronisation.
///
/// Local changes trigger a sync a moment later; the app also syncs when it
/// opens and returns to the foreground. Without a signed-in user nothing
/// leaves the device.
class AccountController extends ChangeNotifier with WidgetsBindingObserver {
  AccountController({
    required AppController app,
    required PlannerController planner,
    AuthService? auth,
    SyncEngine? engine,
  })  : _app = app,
        _planner = planner,
        _auth = auth,
        _engine = engine;

  final AppController _app;
  final PlannerController _planner;
  final AuthService? _auth;
  final SyncEngine? _engine;

  StreamSubscription<void>? _authSub;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  bool _applying = false;
  bool _started = false;

  SyncStatus _status = SyncStatus.localOnly;
  DateTime? _lastSyncedAt;

  bool get configured => _auth != null && _engine != null;
  bool get signedIn => _auth?.userId != null;
  String? get email => _auth?.email;
  SyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  void start() {
    if (!configured || _started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _authSub = _auth!.changes.listen((_) => _refreshStatus());
    _app.addListener(_onLocalChange);
    _planner.addListener(_onLocalChange);
    _refreshStatus();
    if (signedIn) syncNow();
  }

  void _refreshStatus() {
    if (!configured) {
      _status = SyncStatus.localOnly;
    } else if (!signedIn) {
      _status = SyncStatus.signedOut;
    } else if (_status == SyncStatus.signedOut || _status == SyncStatus.localOnly) {
      _status = SyncStatus.idle;
    }
    notifyListeners();
  }

  void _onLocalChange() {
    if (_applying || !signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  Future<void> syncNow() async {
    final uid = _auth?.userId;
    if (!configured || uid == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _debounce?.cancel();
    _status = SyncStatus.syncing;
    notifyListeners();
    try {
      final changed = await _engine!.run(userId: uid);
      if (changed) {
        _applying = true;
        try {
          await _planner.load();
          await _app.reloadProfile();
        } finally {
          _applying = false;
        }
      }
      _lastSyncedAt = DateTime.now();
      _status = SyncStatus.idle;
    } catch (_) {
      // Offline or server unreachable: data stays safe on the device and
      // the next trigger retries.
      _status = SyncStatus.offline;
    } finally {
      _running = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  // ------------------------------------------------------------- account

  Future<void> signIn(String email, String password) async {
    await _auth!.signIn(email, password);
    _refreshStatus();
    await syncNow();
  }

  /// True when signed in immediately; false when a code was emailed.
  Future<bool> signUp(String email, String password) async {
    final signedInNow = await _auth!.signUp(email, password);
    _refreshStatus();
    if (signedInNow) await syncNow();
    return signedInNow;
  }

  Future<void> verifySignUp(String email, String code) async {
    await _auth!.verifySignUp(email, code);
    _refreshStatus();
    await syncNow();
  }

  Future<void> sendPasswordReset(String email) => _auth!.sendPasswordReset(email);

  Future<void> resetPassword(String email, String code, String newPassword) async {
    await _auth!.resetPassword(email, code, newPassword);
    _refreshStatus();
    await syncNow();
  }

  /// Uploads pending changes, signs out and removes this account's data
  /// from the device (it stays safe in the cloud).
  Future<void> signOut() async {
    await syncNow();
    await _auth!.signOut();
    await _wipeDevice();
  }

  /// Permanently deletes the account, its cloud data and the data on this device.
  Future<void> deleteAccount() async {
    await _auth!.deleteAccount();
    await _wipeDevice();
  }

  Future<void> _wipeDevice() async {
    _debounce?.cancel();
    _applying = true;
    try {
      await _planner.clearAll();
      await _app.clearProfile();
      await _engine?.reset();
    } finally {
      _applying = false;
    }
    _lastSyncedAt = null;
    _refreshStatus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _authSub?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _app.removeListener(_onLocalChange);
      _planner.removeListener(_onLocalChange);
    }
    super.dispose();
  }
}

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({super.key, required AccountController controller, required super.child})
      : super(notifier: controller);

  static AccountController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  static AccountController read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AccountScope>()!.widget as AccountScope).notifier!;
}
