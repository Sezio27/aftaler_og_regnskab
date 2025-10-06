import 'package:aftaler_og_regnskab/services/firebase_auth_methods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../model/onboardingModel.dart';
import '../data/user_repository.dart';

/// ViewModel (ChangeNotifier) that the UI listens to.
/// - Holds current [OnboardingModel] state
/// - Exposes update methods per field
/// - Performs save() via the repository

enum NextStep { home, onboarding, loginNoAccount }

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel(this._repo, {OnboardingModel? initial})
    : _state = initial ?? OnboardingModel.empty;

  final UserRepository _repo;

  OnboardingModel _state;
  OnboardingModel get state => _state;

  String _currentDial = '+45';
  String get currentDial => _currentDial;

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  // --- Update methods (call these from onChanged/listeners in your screens) ---
  void setEmail(String v) => _set(_state.copyWith(email: v.trim()));
  void setFirstName(String v) => _set(_state.copyWith(firstName: v.trim()));
  void setLastName(String v) => _set(_state.copyWith(lastName: v.trim()));
  void setBusinessName(String v) =>
      _set(_state.copyWith(businessName: v.trim()));
  void setAddress(String v) => _set(_state.copyWith(address: v.trim()));
  void setCity(String v) => _set(_state.copyWith(city: v.trim()));
  void setPostal(String v) => _set(_state.copyWith(postal: v.trim()));

  bool _attemptLogin = false;
  bool get attemptLogin => _attemptLogin;
  void setAttemptLogin(bool v) {
    _attemptLogin = v;
    // no need to notify unless the UI shows different text immediately
  }

  void _set(OnboardingModel next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  void setCurrentDial(String dial) {
    final prevDial = _currentDial;
    _currentDial = dial;

    final nat = nationalForDial(prevDial);
    setPhoneWithDial(dial: _currentDial, national: nat);
  }

  void setPhoneWithDial({required String dial, required String national}) {
    final nat = national.replaceAll(' ', '');
    _set(_state.copyWith(phone: '$dial$nat'));
  }

  String nationalForDial(String dial) {
    final full = (_state.phone ?? '').replaceAll(' ', '');
    return full.startsWith(dial) ? full.substring(dial.length) : full;
  }

  bool isPhoneValidFor(String dial, {int minNationalLen = 8}) {
    final nat = nationalForDial(dial);
    return nat.length >= minNationalLen;
  }

  bool _isValidEmail(String? s) {
    final v = (s ?? '').trim();
    return _emailRe.hasMatch(v);
  }

  Future<bool> profileExists() => _repo.userDocExists();

  Future<void> confirmAndRoute({
    required String smsCode,
    required FirebaseAuthMethods auth,
    required Future<void> Function() goHome,
    required Future<void> Function() goOnboarding,
    required Future<void> Function()
    loginNoAccount, // will be called if attemptLogin && no profile
    Future<void> Function(Object error)? onError, // optional UI error handler
  }) async {
    try {
      await confirmCode(smsCode: smsCode, auth: auth);
      final exists = await profileExists();

      if (exists) {
        await goHome();
        return;
      }

      if (attemptLogin) {
        await loginNoAccount();
        _attemptLogin = false;
      } else {
        await goOnboarding();
      }
    } catch (e) {
      if (onError != null) await onError(e);
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  // --- Verification session (VM-owned) ---
  String? _verificationId;
  int? _resendToken;
  String _fullPhoneForSession = '';

  String get fullPhoneForSession => _fullPhoneForSession;
  bool get hasVerificationSession => _verificationId != null;

  /// Builds full phone (from state or dial+national) and starts verification.
  /// Stores verificationId/resendToken in the VM for the next screen.
  Future<void> startPhoneVerification(FirebaseAuthMethods auth) async {
    // Prefer state.phone; otherwise combine currentDial + national
    final full = _state.phone?.trim();
    final fullPhone = (full?.isNotEmpty == true)
        ? full!
        : '$currentDial${nationalForDial(currentDial)}';

    final (vId, rTok) = await auth.startPhoneVerification(fullPhone);
    _fullPhoneForSession = fullPhone;
    _verificationId = vId;
    _resendToken = rTok;
    // notify if your UI shows the phone subtitle immediately
    notifyListeners();
  }

  /// Resend code; keep cooldown timer in the View.
  Future<({String verificationId, int? resendToken})> resendCode(
    FirebaseAuthMethods auth,
  ) async {
    if (_fullPhoneForSession.isEmpty) {
      throw StateError(
        'No phone in session. Call startPhoneVerification first.',
      );
    }
    final (vId, rTok) = await auth.startPhoneVerification(
      _fullPhoneForSession,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
    );
    _verificationId = vId;
    _resendToken = rTok;
    return (verificationId: vId, resendToken: rTok);
  }

  /// Confirm code then decide: existing user -> Home, otherwise -> onboarding.
  Future<void> confirmCode({
    required String smsCode,
    required FirebaseAuthMethods auth,
  }) async {
    final vId = _verificationId;
    if (vId == null) {
      throw StateError('No verificationId. Start or seed the session first.');
    }
    await auth.confirmSmsCode(verificationId: vId, smsCode: smsCode);
  }

  bool get isPhoneValid => isPhoneValidFor(_currentDial, minNationalLen: 8);

  String get currentNational => nationalForDial(_currentDial);

  bool get isEmailValid => _isValidEmail(_state.email);
  bool get isFirstNameValid => (_state.firstName ?? '').trim().isNotEmpty;
  bool get isLastNameValid => (_state.lastName ?? '').trim().isNotEmpty;
  bool get isBusinessNameValid => (_state.businessName ?? '').trim().isNotEmpty;
  bool get isAddressValid => (_state.address ?? '').trim().isNotEmpty;
  bool get isCityValid => (_state.city ?? '').trim().isNotEmpty;
  bool get isPostalValid => (_state.postal ?? '').trim().isNotEmpty;

  String? get phone => _state.phone;
  String? get email => _state.email;
  String? get firstName => _state.firstName;
  String? get lastName => _state.lastName;
  String? get businessName => _state.businessName;
  String? get address => _state.address;
  String? get city => _state.city;
  String? get postal => _state.postal;

  /// Saves to Firestore + updates Auth (as implemented in your repository).
  /// Throws on error so the View can show a SnackBar.
  Future<void> save() async {
    await _repo.saveOnboarding(_state);
  }

  /// Clears ephemeral state after successful save or if the user cancels.
  void clear() {
    _state = OnboardingModel.empty;
    notifyListeners();
  }
}
