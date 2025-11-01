// test/view_models/user_view_model_test.dart
import 'dart:async';

import 'package:aftaler_og_regnskab/data/user_repository.dart';
import 'package:aftaler_og_regnskab/services/notification_service.dart';
import 'package:aftaler_og_regnskab/viewModel/appointment_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/user_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  bool opened = false;

  @override
  Future<bool> openAppSettings() async {
    opened = true;
    // Simulate user visiting settings but not enabling notifications.
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockUserRepository extends Mock implements UserRepository {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAppointmentVM extends Mock implements AppointmentViewModel {}

class MockDocSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserRepository repo;
  late MockNotificationService ns;
  late StreamController<DocumentSnapshot<Map<String, dynamic>>?> userStreamCtrl;

  // NEW: capture & replace the PermissionHandler platform instance
  late PermissionHandlerPlatform realPermissions;
  late _FakePermissionHandlerPlatform fakePermissions;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MockUserRepository();
    ns = MockNotificationService();
    userStreamCtrl =
        StreamController<DocumentSnapshot<Map<String, dynamic>>?>.broadcast();

    when(() => repo.userDocStream()).thenAnswer((_) => userStreamCtrl.stream);
    when(() => repo.fetchUserDoc()).thenAnswer((_) async => null);
    when(() => repo.patchUserData(any())).thenAnswer((_) async {});

    when(() => ns.areEnabled()).thenAnswer((_) async => true);
    when(() => ns.requestAllIfNeeded()).thenAnswer((_) async => true);
    when(() => ns.applyEnabled(any())).thenAnswer((_) async {});

    // Install fake permission platform so openAppSettings() won't hit a channel.
    realPermissions = PermissionHandlerPlatform.instance;
    fakePermissions = _FakePermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = fakePermissions;
  });

  tearDown(() async {
    // Restore the real platform instance.
    PermissionHandlerPlatform.instance = realPermissions;
    await userStreamCtrl.close();
  });
  group('constructor: _fetchOnce + _startListening', () {
    test(
      'initial fetch populates business & theme; stream updates afterwards',
      () async {
        // One-shot fetch doc
        final fetchDoc = MockDocSnapshot();
        when(() => fetchDoc.exists).thenReturn(true);
        when(() => fetchDoc.data()).thenReturn({
          'business': {
            'name': 'Salon A',
            'address': 'Main St 1',
            'city': 'Copenhagen',
            'postal': '2100',
          },
          'prefs': {'theme': 'dark'},
        });
        when(() => repo.fetchUserDoc()).thenAnswer((_) async => fetchDoc);

        // Stream doc to override later
        final streamDoc = MockDocSnapshot();
        when(() => streamDoc.exists).thenReturn(true);
        when(() => streamDoc.data()).thenReturn({
          'business': {
            'name': 'Salon B',
            'address': 'Side St 2',
            'city': 'Århus',
            'postal': '8000',
          },
          'prefs': {'theme': 'light'},
        });

        final vm = UserViewModel(repo); // triggers fetch + subscribe

        // Give event loop a tick for _fetchOnce to complete
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // From fetch
        expect(vm.businessName, 'Salon A');
        expect(vm.address, 'Main St 1');
        expect(vm.city, 'Copenhagen');
        expect(vm.postal, '2100');
        expect(vm.themeMode, ThemeMode.dark);

        // Then the stream updates
        userStreamCtrl.add(streamDoc);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(vm.businessName, 'Salon B');
        expect(vm.address, 'Side St 2');
        expect(vm.city, 'Århus');
        expect(vm.postal, '8000');
        expect(vm.themeMode, ThemeMode.light);

        // Firestore theme writes also to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('themeMode'), 'light');

        verify(() => repo.userDocStream()).called(1);
        verify(() => repo.fetchUserDoc()).called(1);
      },
    );
  });

  group('setThemeMode', () {
    test(
      'updates local, writes SharedPreferences, patches Firestore',
      () async {
        final vm = UserViewModel(repo, initialThemeMode: ThemeMode.system);

        await vm.setThemeMode(ThemeMode.dark);

        expect(vm.themeMode, ThemeMode.dark);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('themeMode'), 'dark');

        verify(() => repo.patchUserData({'prefs.theme': 'dark'})).called(1);
      },
    );

    test('no-ops if mode unchanged', () async {
      final vm = UserViewModel(repo, initialThemeMode: ThemeMode.light);
      await vm.setThemeMode(ThemeMode.light);
      verifyNever(() => repo.patchUserData(any()));
    });
  });

  group('initNotificationsIfFirstRun', () {
    test(
      'first run: asks OS, persists flags, applies, updates state (granted)',
      () async {
        when(() => ns.requestAllIfNeeded()).thenAnswer((_) async => true);

        final vm = UserViewModel(repo);
        await vm.initNotificationsIfFirstRun(ns);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('askedNotificationsOnce'), isTrue);
        expect(prefs.getBool('notificationsOn'), isTrue);
        expect(vm.notificationsOn, isTrue);

        verify(() => ns.requestAllIfNeeded()).called(1);
        verify(() => ns.applyEnabled(true)).called(1);
      },
    );

    test('first run denied: turns off + applies false', () async {
      when(() => ns.requestAllIfNeeded()).thenAnswer((_) async => false);

      final vm = UserViewModel(repo);
      await vm.initNotificationsIfFirstRun(ns);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('askedNotificationsOnce'), isTrue);
      expect(prefs.getBool('notificationsOn'), isFalse);
      expect(vm.notificationsOn, isFalse);

      verify(() => ns.applyEnabled(false)).called(1);
    });

    test('not first run: does nothing', () async {
      SharedPreferences.setMockInitialValues({'askedNotificationsOnce': true});

      final vm = UserViewModel(repo);
      await vm.initNotificationsIfFirstRun(ns);

      verifyNever(() => ns.requestAllIfNeeded());
      // no change in prefs/enable calls required
    });
  });

  group('loadLocalPreferences', () {
    test(
      'loads theme + desired notification state; coerces by OS; applies',
      () async {
        // Local wants dark + notificationsOn=false
        SharedPreferences.setMockInitialValues({
          'themeMode': 'dark',
          'notificationsOn': false,
        });
        when(() => ns.areEnabled()).thenAnswer((_) async => true);

        final vm = UserViewModel(repo, initialThemeMode: ThemeMode.system);
        await vm.loadLocalPreferences(ns);

        expect(vm.themeMode, ThemeMode.dark);
        expect(vm.notificationsOn, isFalse);
        verify(() => ns.applyEnabled(false)).called(1);
      },
    );

    test('OS disabled forces effective OFF even if local wants true', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'light',
        'notificationsOn': true,
      });
      when(() => ns.areEnabled()).thenAnswer((_) async => false);

      final vm = UserViewModel(repo, initialThemeMode: ThemeMode.system);
      await vm.loadLocalPreferences(ns);

      expect(vm.themeMode, ThemeMode.light);
      expect(vm.notificationsOn, isFalse);
      verify(() => ns.applyEnabled(false)).called(1);
    });
  });

  group('setNotificationsOn', () {
    test(
      'turn ON: OS already granted → persists, applies, seeds all via apptVM',
      () async {
        when(() => ns.areEnabled()).thenAnswer((_) async => true);
        final apptVM = MockAppointmentVM();
        when(
          () => apptVM.rescheduleTodayAndFuture(ns),
        ).thenAnswer((_) async {});

        final vm = UserViewModel(repo);
        await vm.setNotificationsOn(true, ns, apptVM: apptVM);

        expect(vm.notificationsOn, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notificationsOn'), isTrue);

        verify(() => ns.applyEnabled(true)).called(1);
        verify(() => apptVM.rescheduleTodayAndFuture(ns)).called(1);
      },
    );

    test('turn OFF: persists false and applies false', () async {
      final vm = UserViewModel(repo);
      await vm.setNotificationsOn(false, ns);

      expect(vm.notificationsOn, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notificationsOn'), isFalse);
      verify(() => ns.applyEnabled(false)).called(1);
    });

    test('turn ON: OS disabled then request grants → proceeds ON', () async {
      when(() => ns.areEnabled()).thenAnswer((_) async => false);
      when(() => ns.requestAllIfNeeded()).thenAnswer((_) async => true);

      final vm = UserViewModel(repo);
      await vm.setNotificationsOn(true, ns);

      expect(vm.notificationsOn, isTrue);
      verify(() => ns.applyEnabled(true)).called(1);
    });

    test(
      'turn ON: OS disabled and user refuses even after request → stays OFF and applied false',
      () async {
        when(() => ns.areEnabled()).thenAnswer((_) async => false);
        when(() => ns.requestAllIfNeeded()).thenAnswer((_) async => false);

        final vm = UserViewModel(repo);
        await vm.setNotificationsOn(true, ns);

        expect(vm.notificationsOn, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notificationsOn'), isFalse);
        verify(() => ns.applyEnabled(false)).called(1);

        // NEW: prove openAppSettings() was called, but without crashing
        expect(fakePermissions.opened, isTrue);
      },
    );
  });

  group('onAuthChanged', () {
    test('cancels old sub, restarts listening and fetches once', () async {
      // First cycle
      final firstDoc = MockDocSnapshot();
      when(() => firstDoc.exists).thenReturn(true);
      when(() => firstDoc.data()).thenReturn({
        'business': {'name': 'First'},
      });

      // Second cycle
      final secondCtrl =
          StreamController<DocumentSnapshot<Map<String, dynamic>>?>.broadcast();
      final secondDoc = MockDocSnapshot();
      when(() => secondDoc.exists).thenReturn(true);
      when(() => secondDoc.data()).thenReturn({
        'business': {'name': 'Second'},
      });

      when(() => repo.fetchUserDoc()).thenAnswer((_) async => firstDoc);
      final vm = UserViewModel(repo);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.businessName, 'First');

      // onAuthChanged: switch to a new stream + new fetch
      when(() => repo.userDocStream()).thenAnswer((_) => secondCtrl.stream);
      when(() => repo.fetchUserDoc()).thenAnswer((_) async => secondDoc);

      await vm.onAuthChanged();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // New fetch applied
      expect(vm.businessName, 'Second');

      // Stream also applies
      final streamed = MockDocSnapshot();
      when(() => streamed.exists).thenReturn(true);
      when(() => streamed.data()).thenReturn({
        'business': {'name': 'SecondStream'},
      });
      secondCtrl.add(streamed);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.businessName, 'SecondStream');

      await secondCtrl.close();
      verify(() => repo.userDocStream()).called(greaterThanOrEqualTo(2));
      verify(() => repo.fetchUserDoc()).called(greaterThanOrEqualTo(2));
    });
  });

  group('dispose', () {
    test('cancels subscription', () async {
      final vm = UserViewModel(repo);

      // Ensure the subscription is active
      expect(userStreamCtrl.hasListener, isTrue);

      vm.dispose();

      // No listener remains
      expect(userStreamCtrl.hasListener, isFalse);
    });
  });
}
