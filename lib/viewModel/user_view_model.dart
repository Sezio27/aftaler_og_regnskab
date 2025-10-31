import 'dart:async';

import 'package:aftaler_og_regnskab/data/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _toString(mode));

    await _repo.patchUserData({'prefs.theme': _toString(mode)});
  }

  Future<void> loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _fromString(prefs.getString(_prefsKey) ?? 'system');
    if (local != _themeMode) {
      _themeMode = local;
      notifyListeners();
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
