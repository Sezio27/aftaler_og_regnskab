import 'package:aftaler_og_regnskab/model/onboarding_model.dart';
import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:aftaler_og_regnskab/viewModel/onboarding_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aftaler_og_regnskab/data/user_repository.dart';

import 'package:firebase_auth/firebase_auth.dart';

class MockUserCredential extends Mock implements UserCredential {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAuth extends Mock implements FirebaseAuthMethods {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserRepository repo;
  late MockAuth auth;

  setUpAll(() {
    registerFallbackValue(OnboardingModel.empty);
    registerFallbackValue(const Duration(seconds: 60));
  });

  setUp(() {
    repo = MockUserRepository();
    auth = MockAuth();

    // Safe defaults
    when(() => repo.userDocExists()).thenAnswer((_) async => false);
    when(() => repo.saveOnboarding(any())).thenAnswer((_) async {});
    when(
      () => auth.startPhoneVerification(
        any(),
        forceResendingToken: any(named: 'forceResendingToken'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => ('vid-1', 7));
    when(
      () => auth.confirmSmsCode(
        verificationId: any(named: 'verificationId'),
        smsCode: any(named: 'smsCode'),
      ),
    ).thenAnswer((_) async => MockUserCredential());
  });

  group('field setters & validation', () {
    test('email, names, business/address fields update state', () {
      final vm = OnboardingViewModel(repo);

      vm.setEmail('  a@b.com  ');
      vm.setFirstName(' Alice ');
      vm.setLastName(' Doe ');
      vm.setBusinessName(' My Biz ');
      vm.setAddress(' Addr ');
      vm.setCity(' City ');
      vm.setPostal(' 1234 ');

      expect(vm.email, 'a@b.com');
      expect(vm.firstName, 'Alice');
      expect(vm.lastName, 'Doe');
      expect(vm.businessName, 'My Biz');
      expect(vm.address, 'Addr');
      expect(vm.city, 'City');
      expect(vm.postal, '1234');

      expect(vm.isEmailValid, isTrue);
      expect(vm.isFirstNameValid, isTrue);
      expect(vm.isLastNameValid, isTrue);
      expect(vm.isBusinessNameValid, isTrue);
      expect(vm.isAddressValid, isTrue);
      expect(vm.isCityValid, isTrue);
      expect(vm.isPostalValid, isTrue);
    });

    test('email validation fails for bad formats', () {
      final vm = OnboardingViewModel(repo);
      vm.setEmail('not-an-email');
      expect(vm.isEmailValid, isFalse);
      vm.setEmail('a@b');
      expect(vm.isEmailValid, isFalse);
    });

    test(
      'phone helpers: setPhoneWithDial / nationalForDial / isPhoneValid',
      () {
        final vm = OnboardingViewModel(repo);

        vm.setPhoneWithDial(dial: '+45', national: '12 34 56 78');
        expect(vm.phone, '+4512345678');
        expect(vm.nationalForDial('+45'), '12345678');
        expect(vm.isPhoneValidFor('+45', minNationalLen: 8), isTrue);
        expect(vm.isPhoneValid, isTrue);

        // Too short national part
        vm.setPhoneWithDial(dial: '+45', national: '1234');
        expect(vm.isPhoneValid, isFalse);
      },
    );

    test('setCurrentDial preserves national number and rewrites phone', () {
      final vm = OnboardingViewModel(repo);

      vm.setPhoneWithDial(dial: '+45', national: '12345678');
      expect(vm.phone, '+4512345678');

      vm.setCurrentDial('+1'); // should remap to +1 + same national
      expect(vm.currentDial, '+1');
      expect(vm.phone, '+112345678');
      expect(vm.currentNational, '12345678');
    });
  });

  group('verification session', () {
    test('startPhoneVerification stores session and notifies', () async {
      final vm = OnboardingViewModel(repo);
      vm.setPhoneWithDial(dial: '+45', national: '88887777');

      when(
        () => auth.startPhoneVerification('+4588887777'),
      ).thenAnswer((_) async => ('vid-xyz', 42));

      await vm.startPhoneVerification(auth);

      expect(vm.hasVerificationSession, isTrue);
      expect(vm.fullPhoneForSession, '+4588887777');
      // Private tokens can be indirectly checked via confirmCode later
    });

    test('resendCode throws if no session yet', () async {
      final vm = OnboardingViewModel(repo);

      expect(() => vm.resendCode(auth), throwsA(isA<StateError>()));
    });

    test(
      'resendCode uses stored phone and passes forceResendingToken',
      () async {
        final vm = OnboardingViewModel(repo);
        vm.setPhoneWithDial(dial: '+45', national: '99998888');

        when(
          () => auth.startPhoneVerification('+4599998888'),
        ).thenAnswer((_) async => ('vid-a', 7));
        await vm.startPhoneVerification(auth);

        when(
          () => auth.startPhoneVerification(
            '+4599998888',
            forceResendingToken: 7,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => ('vid-b', 8));

        final r = await vm.resendCode(auth);
        expect(r.verificationId, 'vid-b');
        expect(r.resendToken, 8);
      },
    );

    test('confirmCode throws when no verificationId set', () async {
      final vm = OnboardingViewModel(repo);
      await expectLater(
        vm.confirmCode(smsCode: '123456', auth: auth),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'confirmCode calls auth.confirmSmsCode with stored verificationId',
      () async {
        final vm = OnboardingViewModel(repo);
        vm.setPhoneWithDial(dial: '+45', national: '12345678');

        when(
          () => auth.startPhoneVerification('+4512345678'),
        ).thenAnswer((_) async => ('vid-12', 1));

        await vm.startPhoneVerification(auth);
        await vm.confirmCode(smsCode: '000999', auth: auth);

        verify(
          () =>
              auth.confirmSmsCode(verificationId: 'vid-12', smsCode: '000999'),
        ).called(1);
      },
    );
  });

  group('confirmAndRoute', () {
    test('existing profile → goHome', () async {
      final vm = OnboardingViewModel(repo);
      vm.setPhoneWithDial(dial: '+45', national: '12345678');

      when(
        () => auth.startPhoneVerification(any()),
      ).thenAnswer((_) async => ('vid-1', 1));
      when(() => repo.userDocExists()).thenAnswer((_) async => true);

      await vm.startPhoneVerification(auth);

      var goHomeCalled = false;
      var goOnCalled = false;
      var loginNoAccountCalled = false;

      await vm.confirmAndRoute(
        smsCode: '111222',
        auth: auth,
        goHome: () async => goHomeCalled = true,
        goOnboarding: () async => goOnCalled = true,
        loginNoAccount: () async => loginNoAccountCalled = true,
      );

      expect(goHomeCalled, isTrue);
      expect(goOnCalled, isFalse);
      expect(loginNoAccountCalled, isFalse);
    });

    test(
      'no profile + attemptLogin=true → loginNoAccount and reset flag',
      () async {
        final vm = OnboardingViewModel(repo);
        vm.setPhoneWithDial(dial: '+45', national: '12345678');
        vm.setAttemptLogin(true);

        when(() => repo.userDocExists()).thenAnswer((_) async => false);
        await vm.startPhoneVerification(auth);

        var loginNoAccountCalled = false;

        await vm.confirmAndRoute(
          smsCode: '333444',
          auth: auth,
          goHome: () async {},
          goOnboarding: () async {},
          loginNoAccount: () async => loginNoAccountCalled = true,
        );

        expect(loginNoAccountCalled, isTrue);
        expect(vm.attemptLogin, isFalse);
      },
    );

    test('no profile + attemptLogin=false → goOnboarding', () async {
      final vm = OnboardingViewModel(repo);
      vm.setPhoneWithDial(dial: '+45', national: '87654321');

      when(() => repo.userDocExists()).thenAnswer((_) async => false);
      await vm.startPhoneVerification(auth);

      var goOnCalled = false;

      await vm.confirmAndRoute(
        smsCode: '555666',
        auth: auth,
        goHome: () async {},
        goOnboarding: () async => goOnCalled = true,
        loginNoAccount: () async {},
      );

      expect(goOnCalled, isTrue);
    });

    test('error path: confirm throws → onError invoked, no routes', () async {
      final vm = OnboardingViewModel(repo);
      vm.setPhoneWithDial(dial: '+45', national: '22223333');
      await vm.startPhoneVerification(auth);

      when(
        () => auth.confirmSmsCode(
          verificationId: any(named: 'verificationId'),
          smsCode: any(named: 'smsCode'),
        ),
      ).thenThrow(Exception('bad code'));

      Object? captured;
      var anyRouteCalled = false;

      await vm.confirmAndRoute(
        smsCode: '000000',
        auth: auth,
        goHome: () async => anyRouteCalled = true,
        goOnboarding: () async => anyRouteCalled = true,
        loginNoAccount: () async => anyRouteCalled = true,
        onError: (e) async => captured = e,
      );

      expect(anyRouteCalled, isFalse);
      expect(captured, isA<Exception>());
    });
  });

  group('save & clear', () {
    test('save delegates to repository with current state', () async {
      final vm = OnboardingViewModel(repo);

      vm
        ..setEmail('a@b.com')
        ..setFirstName('A')
        ..setLastName('B')
        ..setBusinessName('Biz')
        ..setAddress('Road 1')
        ..setCity('Cph')
        ..setPostal('2100')
        ..setPhoneWithDial(dial: '+45', national: '12345678');

      await vm.save();

      verify(
        () => repo.saveOnboarding(
          any(
            that: isA<OnboardingModel>()
                .having((m) => m.email, 'email', 'a@b.com')
                .having((m) => m.firstName, 'first', 'A')
                .having((m) => m.businessName, 'biz', 'Biz')
                .having((m) => m.phone, 'phone', '+4512345678'),
          ),
        ),
      ).called(1);
    });

    test('clear resets state to empty', () {
      final vm = OnboardingViewModel(repo);
      vm
        ..setEmail('x@y.z')
        ..setFirstName('X')
        ..setBusinessName('B');
      vm.clear();

      expect(vm.state, equals(OnboardingModel.empty));
      expect(vm.email, isNull);
      expect(vm.firstName, isNull);
      expect(vm.businessName, isNull);
    });
  });

  group('profileExists', () {
    test('delegates to repository', () async {
      when(() => repo.userDocExists()).thenAnswer((_) async => true);
      final vm = OnboardingViewModel(repo);
      expect(await vm.profileExists(), isTrue);

      when(() => repo.userDocExists()).thenAnswer((_) async => false);
      expect(await vm.profileExists(), isFalse);
    });
  });
}
