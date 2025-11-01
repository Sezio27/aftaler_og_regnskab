import 'dart:async';

import 'package:aftaler_og_regnskab/data/user_repository.dart';
import 'package:aftaler_og_regnskab/services/notification_service.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserViewModel extends ChangeNotifier {
  UserViewModel(this._repo, {ThemeMode? initialThemeMode})
    : _themeMode = initialThemeMode ?? ThemeMode.system {
    _startListening();
    _fetchOnce();
  }

  final UserRepository _repo;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>?>? _sub;

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  String _businessName = '';
  String _address = '';
  String _city = '';
  String _postal = '';
  static const _prefsKey = 'themeMode';

  String get businessName => _businessName;
  String get address => _address;
  String get city => _city;
  String get postal => _postal;

  static const _prefsKeyTheme = 'themeMode';
  static const _prefsKeyNoti = 'notificationsOn';
  static const _prefsKeyAskedOnce = 'askedNotificationsOnce';

  bool _notificationsOn = true;
  bool get notificationsOn => _notificationsOn;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _toString(mode));

    await _repo.patchUserData({'prefs.theme': _toString(mode)});
  }

  Future<void> initNotificationsIfFirstRun(NotificationService ns) async {
    final sp = await SharedPreferences.getInstance();
    final asked = sp.getBool(_prefsKeyAskedOnce) ?? false;
    if (!asked) {
      // First ever run → ask OS once
      final granted = await ns.requestAllIfNeeded();
      _notificationsOn = granted; // reflect OS decision
      await sp.setBool(_prefsKeyNoti, _notificationsOn);
      await sp.setBool(_prefsKeyAskedOnce, true);
      await ns.applyEnabled(_notificationsOn);
      notifyListeners();
    }
  }

  Future<void> loadLocalPreferences(NotificationService ns) async {
    final sp = await SharedPreferences.getInstance();

    // theme
    final localTheme = _fromString(sp.getString(_prefsKeyTheme) ?? 'system');
    if (localTheme != _themeMode) _themeMode = localTheme;

    // notifications (app-level desired state)
    final localNoti = sp.getBool(_prefsKeyNoti);
    final osEnabled = await ns.areEnabled();

    // If OS blocked, effective is OFF no matter what local says
    _notificationsOn = osEnabled && (localNoti ?? true);

    // Make service match effective state
    await ns.applyEnabled(_notificationsOn);

    notifyListeners();
  }

  Future<void> setNotificationsOn(
    bool on,
    NotificationService ns, {
    AppointmentViewModel? apptVM,
    BuildContext? contextForSnackBar,
  }) async {
    if (on) {
      var granted = await ns.areEnabled();
      if (!granted) {
        granted = await ns.requestAllIfNeeded();
        if (!granted) {
          // iOS & some Android cases require opening Settings after denial
          await openAppSettings(); // from permission_handler
          granted = await ns.areEnabled();
          if (!granted) {
            // keep OFF – user didn’t enable in settings
            _notificationsOn = false;
            notifyListeners();
            final sp = await SharedPreferences.getInstance();
            await sp.setBool(_prefsKeyNoti, _notificationsOn);
            await ns.applyEnabled(false);
            return;
          }
        }
      }

      // OS is granted; app-level ON
      _notificationsOn = true;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_prefsKeyNoti, true);
      await ns.applyEnabled(true);

      // Seed ALL: today + all future
      if (apptVM != null) {
        await apptVM.rescheduleTodayAndFuture(ns);
      }
      notifyListeners();
    } else {
      // App-level kill switch OFF (even if OS grants)
      _notificationsOn = false;
      notifyListeners();
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_prefsKeyNoti, false);
      await ns.applyEnabled(false); // also cancels all
    }
  }

  Future<void> _startListening() async {
    _sub = _repo.userDocStream().listen((snapshot) async {
      if (snapshot == null || !snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      // Business info
      final business = data['business'] as Map<String, dynamic>?;
      _businessName = (business?['name'] as String?)?.trim() ?? '';
      _address = (business?['address'] as String?)?.trim() ?? '';
      _city = (business?['city'] as String?)?.trim() ?? '';
      _postal = (business?['postal'] as String?)?.trim() ?? '';

      // Theme from Firestore: prefs.theme = 'light'|'dark'|'system'
      final remote = (data['prefs'] as Map?)?['theme'] as String?;
      if (remote != null) {
        final remoteMode = _fromString(remote);
        if (remoteMode != _themeMode) {
          _themeMode = remoteMode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, _toString(remoteMode));
        }
      }

      notifyListeners();
    });
  }

  Future<void> _fetchOnce() async {
    final doc = await _repo.fetchUserDoc();
    if (doc == null || !doc.exists) return;
    final data = doc.data();
    if (data == null) return;

    final business = data['business'] as Map<String, dynamic>?;
    _businessName = (business?['name'] as String?)?.trim() ?? '';
    _address = (business?['address'] as String?)?.trim() ?? '';
    _city = (business?['city'] as String?)?.trim() ?? '';
    _postal = (business?['postal'] as String?)?.trim() ?? '';

    final remote = (data['prefs'] as Map?)?['theme'] as String?;
    if (remote != null) {
      final remoteMode = _fromString(remote);
      if (remoteMode != _themeMode) {
        _themeMode = remoteMode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, _toString(remoteMode));
      }
    }

    notifyListeners();
  }

  Future<void> onAuthChanged() async {
    await _sub?.cancel();
    _sub = null;
    await _startListening();
    await _fetchOnce();
  }

  static ThemeMode _fromString(String v) {
    switch (v) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
